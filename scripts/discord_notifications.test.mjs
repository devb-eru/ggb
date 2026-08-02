import test from "node:test";
import assert from "node:assert/strict";

import {
  buildDailyDigestMessage,
  buildDiscordPayload,
  buildImmediateMessage,
  buildMeetingAgenda,
  buildMeetingAgendaMessage,
  buildProjectMessage,
  collectDailyDigest,
  diffCriticalProjectState,
  mergeProjectStateHistory,
  postDiscord,
  projectItemsToState,
  sanitize,
  validateDiscordWebhookUrl,
} from "./discord_notifications.mjs";

const repo = {
  full_name: "devb-eru/ggb",
  html_url: "https://github.com/devb-eru/ggb",
};

test("push only notifies develop and main", () => {
  const base = {
    repository: repo,
    sender: { login: "beru" },
    size: 1,
    commits: [{ message: "test commit" }],
    compare: "https://github.com/devb-eru/ggb/compare/a...b",
  };
  assert.equal(buildImmediateMessage("push", { ...base, ref: "refs/heads/feature/demo" }), null);
  assert.match(buildImmediateMessage("push", { ...base, ref: "refs/heads/develop" }).title, /develop/);
});

test("pull request filters creation, merge, and change requests", () => {
  const pull_request = {
    number: 42,
    title: "Update scene",
    html_url: "https://github.com/devb-eru/ggb/pull/42",
    base: { ref: "develop" },
    head: { ref: "feature/scene" },
  };
  assert.match(buildImmediateMessage("pull_request", { repository: repo, action: "opened", pull_request }).title, /PR 생성/);
  assert.equal(buildImmediateMessage("pull_request", { repository: repo, action: "closed", pull_request }), null);
  assert.match(
    buildImmediateMessage("pull_request", {
      repository: repo,
      action: "closed",
      pull_request: { ...pull_request, merged: true },
    }).title,
    /병합/,
  );
  assert.equal(
    buildImmediateMessage("pull_request_review", {
      repository: repo,
      pull_request,
      review: { state: "approved" },
    }),
    null,
  );
  assert.match(
    buildImmediateMessage("pull_request_review", {
      repository: repo,
      pull_request,
      review: { state: "changes_requested", user: { login: "niik0203" } },
    }).title,
    /변경 요청/,
  );
});

test("milestone and workflow events only notify meaningful failures or dates", () => {
  const milestone = { title: "M2", due_on: "2026-11-20T00:00:00Z" };
  assert.equal(buildImmediateMessage("milestone", { action: "edited", milestone, changes: { description: {} } }), null);
  assert.match(
    buildImmediateMessage("milestone", { repository: repo, action: "edited", milestone, changes: { due_on: {} } }).title,
    /마일스톤/,
  );
  assert.equal(
    buildImmediateMessage("workflow_run", { repository: repo, workflow_run: { name: "CI", conclusion: "success" } }),
    null,
  );
  assert.match(
    buildImmediateMessage("workflow_run", {
      repository: repo,
      workflow_run: { name: "Validate docs", conclusion: "failure", html_url: "https://example.test" },
    }).title,
    /CI failure/,
  );
});

test("critical labels are a repository fallback", () => {
  const issue = { number: 7, title: "Blocked task", html_url: "https://github.com/devb-eru/ggb/issues/7" };
  assert.equal(buildImmediateMessage("issues", { action: "labeled", label: { name: "docs" }, issue }), null);
  assert.match(
    buildImmediateMessage("issues", { repository: repo, action: "labeled", label: { name: "P1" }, issue }).title,
    /P1/,
  );
});

test("Discord payload strips controls and disables mentions", () => {
  const unsafe = "@everyone\u202E<@123>\u0000";
  const payload = buildDiscordPayload({ title: unsafe, description: unsafe });
  assert.deepEqual(payload.allowed_mentions, { parse: [] });
  assert.doesNotMatch(payload.embeds[0].title, /\u202E|\u0000/);
  assert.doesNotMatch(payload.embeds[0].title, /@everyone/);
  assert.ok(sanitize("x".repeat(1100), 100).length <= 100);
});

test("Discord webhook URL validation is strict", () => {
  assert.equal(validateDiscordWebhookUrl("https://discord.com/api/webhooks/123/token"), true);
  assert.equal(validateDiscordWebhookUrl("https://example.com/api/webhooks/123/token"), false);
  assert.equal(validateDiscordWebhookUrl("http://discord.com/api/webhooks/123/token"), false);
});

test("dry-run never performs a network request", async () => {
  let called = false;
  const result = await postDiscord({
    webhookUrl: "",
    payload: { content: "test" },
    dryRun: true,
    fetchImpl: async () => {
      called = true;
    },
    logger: { log() {} },
  });
  assert.equal(called, false);
  assert.equal(result.dryRun, true);
});

test("Discord retries a rate limit without leaking the webhook", async () => {
  let calls = 0;
  const result = await postDiscord({
    webhookUrl: "https://discord.com/api/webhooks/123/token",
    payload: { content: "test" },
    fetchImpl: async () => {
      calls += 1;
      if (calls === 1) {
        return new Response(JSON.stringify({ retry_after: 0.001 }), {
          status: 429,
          headers: { "content-type": "application/json", "retry-after": "0.001" },
        });
      }
      return new Response("{}", { status: 200 });
    },
    logger: { log() {} },
  });
  assert.equal(calls, 2);
  assert.equal(result.sent, true);
});

test("daily digest collects new Issues, inline comments, and PR reviews", async () => {
  const now = new Date("2026-08-01T12:00:00Z");
  const recent = "2026-08-01T11:00:00Z";
  const old = "2026-07-01T11:00:00Z";
  const json = (value) => new Response(JSON.stringify(value), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
  const fetchImpl = async (input) => {
    const url = new URL(input);
    if (url.pathname.endsWith("/branches")) return json([]);
    if (url.pathname.endsWith("/issues/events")) return json([]);
    if (url.pathname.endsWith("/issues/comments")) return json([]);
    if (url.pathname.endsWith("/pulls/comments")) {
      return json([{
        created_at: recent,
        html_url: "https://github.com/devb-eru/ggb/pull/5#discussion_r1",
        pull_request_url: "https://api.github.com/repos/devb-eru/ggb/pulls/5",
        user: { login: "niik0203", type: "User" },
      }]);
    }
    if (url.pathname.endsWith("/issues")) {
      return json([
        {
          number: 4,
          title: "New task",
          created_at: recent,
          updated_at: recent,
          html_url: "https://github.com/devb-eru/ggb/issues/4",
          user: { login: "devb-eru", type: "User" },
        },
        {
          number: 5,
          title: "Existing PR",
          created_at: old,
          updated_at: recent,
          html_url: "https://github.com/devb-eru/ggb/pull/5",
          pull_request: { url: "https://api.github.com/repos/devb-eru/ggb/pulls/5" },
          user: { login: "devb-eru", type: "User" },
        },
      ]);
    }
    if (url.pathname.endsWith("/pulls/5/reviews")) {
      return json([{
        state: "APPROVED",
        submitted_at: recent,
        html_url: "https://github.com/devb-eru/ggb/pull/5#pullrequestreview-1",
        user: { login: "niik0203", type: "User" },
      }]);
    }
    throw new Error(`Unexpected test URL: ${url}`);
  };

  const digest = await collectDailyDigest({
    token: "test-token",
    repo: "devb-eru/ggb",
    now,
    fetchImpl,
  });
  assert.equal(digest.issueChanges.length, 1);
  assert.equal(digest.issueChanges[0].event, "opened");
  assert.equal(digest.comments.length, 1);
  assert.equal(digest.reviews.length, 1);
  assert.equal(digest.reviews[0].state, "approved");
});

test("daily digest skips empty windows and caps visible fields", () => {
  const empty = { repo: "devb-eru/ggb", commits: [], issueChanges: [], comments: [] };
  assert.equal(buildDailyDigestMessage(empty), null);
  const message = buildDailyDigestMessage({
    ...empty,
    commits: Array.from({ length: 12 }, (_, index) => ({
      branch: "feature/test",
      message: `commit ${index}`,
      author: "beru",
      url: `https://github.com/devb-eru/ggb/commit/${index}`,
    })),
  });
  assert.equal(message.fields.length, 1);
  assert.match(message.fields[0].value, /외 4건/);
});

test("Project state detects only new critical transitions", () => {
  const previous = {
    one: { title: "One", url: "https://example.test/1", status: "READY", priority: "P2" },
  };
  const current = {
    one: { title: "One", url: "https://example.test/1", status: "BLOCKED", priority: "P1" },
    two: { title: "Two", url: "https://example.test/2", status: "IN_PROGRESS", priority: "P2" },
  };
  const changes = diffCriticalProjectState(previous, current);
  assert.equal(changes.length, 1);
  assert.deepEqual(changes[0].reasons, ["BLOCKED", "P1"]);
  assert.match(buildProjectMessage(changes).description, /BLOCKED \+ P1/);
});

test("Project item extraction keeps only this repository", () => {
  const nodes = [
    {
      id: "one",
      content: { title: "Task", url: "https://example.test/1", repository: { nameWithOwner: "devb-eru/ggb" } },
      fieldValues: {
        nodes: [
          { name: "BLOCKED", field: { name: "Status" } },
          { name: "P1", field: { name: "우선순위" } },
          { name: "beru", field: { name: "실제 담당자" } },
          { name: "운영", field: { name: "담당 팀" } },
          { date: "2026-08-03", field: { name: "목표일" } },
          { text: "승인 대기", field: { name: "차단 원인" } },
        ],
      },
    },
    {
      id: "two",
      content: { title: "Other", url: "https://example.test/2", repository: { nameWithOwner: "other/repo" } },
      fieldValues: { nodes: [] },
    },
  ];
  const state = projectItemsToState(nodes, "devb-eru/ggb");
  assert.deepEqual(Object.keys(state), ["one"]);
  assert.equal(state.one.status, "BLOCKED");
  assert.equal(state.one.priority, "P1");
  assert.equal(state.one.actualOwner, "beru");
  assert.equal(state.one.team, "운영");
  assert.equal(state.one.targetDate, "2026-08-03");
  assert.equal(state.one.blockedReason, "승인 대기");
});

test("Project state history preserves or resets the status entry timestamp", () => {
  const now = new Date("2026-08-07T12:30:00Z");
  const previous = {
    one: { status: "READY", statusEnteredAt: "2026-08-01T00:00:00.000Z" },
    two: { status: "IN_PROGRESS", statusEnteredAt: "2026-08-02T00:00:00.000Z" },
  };
  const current = {
    one: { status: "READY", title: "Same" },
    two: { status: "REVIEW", title: "Changed" },
    three: { status: "REVIEW", title: "New" },
  };
  const merged = mergeProjectStateHistory(previous, current, now);
  assert.equal(merged.one.statusEnteredAt, "2026-08-01T00:00:00.000Z");
  assert.equal(merged.two.statusEnteredAt, now.toISOString());
  assert.equal(merged.three.statusEnteredAt, now.toISOString());
});

test("meeting agenda orders categories and lists each item only once", () => {
  const now = new Date("2026-08-07T12:30:00Z");
  const item = (overrides) => ({
    title: "Task",
    url: "https://github.com/devb-eru/ggb/issues/1",
    status: "IN_PROGRESS",
    priority: "P2",
    actualOwner: "beru",
    targetDate: "2026-08-20",
    statusEnteredAt: "2026-08-07T00:00:00.000Z",
    ...overrides,
  });
  const agenda = buildMeetingAgenda({
    critical: item({ number: 1, status: "BLOCKED", priority: "P1", actualOwner: "UNASSIGNED", targetDate: "2026-08-01" }),
    due: item({ number: 2, targetDate: "2026-08-14" }),
    review: item({ number: 3, status: "REVIEW", statusEnteredAt: "2026-08-06T12:29:59.000Z" }),
    overdue: item({ number: 4, targetDate: "2026-08-06" }),
    owner: item({ number: 5, actualOwner: "UNASSIGNED" }),
    done: item({ number: 6, status: "DONE", priority: "P0", actualOwner: null, targetDate: "2026-08-01" }),
  }, now);

  assert.equal(agenda.nextMeetingDate, "2026-08-14");
  assert.deepEqual(agenda.sections.map((section) => section.items.map((entry) => entry.id)), [
    ["critical"],
    ["due"],
    ["review"],
    ["overdue"],
    ["owner"],
  ]);
  const ids = agenda.sections.flatMap((section) => section.items.map((entry) => entry.id));
  assert.equal(new Set(ids).size, ids.length);
});

test("meeting agenda sends a useful message even when no automatic items exist", () => {
  const agenda = buildMeetingAgenda({}, new Date("2026-08-07T12:30:00Z"));
  const message = buildMeetingAgendaMessage(agenda, { PROJECT_URL: "https://github.com/users/devb-eru/projects/1" });
  assert.equal(message.fields.length, 0);
  assert.match(message.title, /주간 제작 회의 안건/);
  assert.match(message.description, /자동 안건이 없습니다/);
  assert.equal(message.url, "https://github.com/users/devb-eru/projects/1");
  assert.equal(buildMeetingAgenda({}, new Date("2026-08-02T12:30:00Z")).nextMeetingDate, "2026-08-07");
});
