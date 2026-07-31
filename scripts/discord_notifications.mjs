import { mkdir, readFile, writeFile, appendFile } from "node:fs/promises";
import { dirname } from "node:path";
import { pathToFileURL } from "node:url";

const COLORS = {
  info: 0x3498db,
  success: 0x2ecc71,
  warning: 0xf1c40f,
  danger: 0xe74c3c,
  neutral: 0x95a5a6,
};

const FAILURE_CONCLUSIONS = new Set([
  "action_required",
  "failure",
  "startup_failure",
  "timed_out",
]);

const CRITICAL_LABELS = new Set(["p0", "p1", "blocked"]);

export function sanitize(value, limit = 1024) {
  const text = String(value ?? "")
    .normalize("NFKC")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/[\u202A-\u202E\u2066-\u2069]/g, "")
    .replace(/@(everyone|here)/gi, "@\u200b$1")
    .replace(/<(@[!&]?\d+)>/g, "<\u200b$1>")
    .trim();

  if (text.length <= limit) return text;
  return `${text.slice(0, Math.max(0, limit - 1))}…`;
}

function firstLine(value) {
  return sanitize(String(value ?? "").split(/\r?\n/, 1)[0], 300);
}

function actorName(payload) {
  return sanitize(
    payload.sender?.login ?? payload.pusher?.name ?? payload.actor?.login ?? "unknown",
    100,
  );
}

function repositoryName(payload, env = {}) {
  return sanitize(payload.repository?.full_name ?? env.GITHUB_REPOSITORY ?? "repository", 100);
}

function repositoryUrl(payload, env = {}) {
  if (payload.repository?.html_url) return payload.repository.html_url;
  const server = env.GITHUB_SERVER_URL ?? "https://github.com";
  const repo = payload.repository?.full_name ?? env.GITHUB_REPOSITORY;
  return repo ? `${server}/${repo}` : server;
}

function field(name, value, inline = false) {
  return {
    name: sanitize(name, 256) || "정보",
    value: sanitize(value, 1024) || "-",
    inline,
  };
}

export function buildImmediateMessage(eventName, payload, env = {}) {
  const repo = repositoryName(payload, env);
  const actor = actorName(payload);

  switch (eventName) {
    case "push": {
      const branch = String(payload.ref ?? "").replace("refs/heads/", "");
      if (!new Set(["develop", "main"]).has(branch)) return null;
      const commits = Array.isArray(payload.commits) ? payload.commits : [];
      const count = Number(payload.size ?? commits.length ?? 0);
      const headMessage = firstLine(payload.head_commit?.message ?? commits.at(-1)?.message);
      return {
        title: `⬆️ ${branch} push`,
        description: `${count}개 커밋이 ${branch}에 반영됐습니다.`,
        url: payload.compare ?? repositoryUrl(payload, env),
        color: branch === "main" ? COLORS.success : COLORS.info,
        fields: [field("실행자", actor, true), field("최신 커밋", headMessage || "정보 없음")],
      };
    }

    case "pull_request": {
      const action = payload.action;
      const pr = payload.pull_request;
      if (!pr) return null;

      const labels = {
        opened: ["🟦 PR 생성", COLORS.info],
        ready_for_review: ["🟪 검토 준비", 0x9b59b6],
        review_requested: ["🟪 검토 요청", 0x9b59b6],
      };

      if (action === "closed") {
        if (!pr.merged) return null;
        return {
          title: `🟩 PR #${pr.number} 병합`,
          description: sanitize(pr.title, 1500),
          url: pr.html_url,
          color: COLORS.success,
          fields: [
            field("병합", `${pr.base?.ref ?? "?"} ← ${pr.head?.ref ?? "?"}`, true),
            field("실행자", actor, true),
          ],
        };
      }

      if (!labels[action]) return null;
      const [label, color] = labels[action];
      const requested = payload.requested_reviewer?.login ?? payload.requested_team?.name;
      const fields = [field("대상", pr.base?.ref ?? "?", true), field("실행자", actor, true)];
      if (requested) fields.push(field("검토자", requested, true));
      return {
        title: `${label} #${pr.number}`,
        description: sanitize(pr.title, 1500),
        url: pr.html_url,
        color,
        fields,
      };
    }

    case "pull_request_review": {
      const review = payload.review;
      const pr = payload.pull_request;
      if (String(review?.state ?? "").toLowerCase() !== "changes_requested" || !pr) return null;
      return {
        title: `🟥 PR #${pr.number} 변경 요청`,
        description: sanitize(pr.title, 1500),
        url: review.html_url ?? pr.html_url,
        color: COLORS.danger,
        fields: [field("검토자", review.user?.login ?? actor, true)],
      };
    }

    case "issues": {
      if (payload.action !== "labeled") return null;
      const labelName = String(payload.label?.name ?? "").toLowerCase();
      if (!CRITICAL_LABELS.has(labelName)) return null;
      const issue = payload.issue;
      if (!issue) return null;
      return {
        title: `🚨 Issue #${issue.number} ${labelName.toUpperCase()}`,
        description: sanitize(issue.title, 1500),
        url: issue.html_url,
        color: labelName === "p0" || labelName === "blocked" ? COLORS.danger : COLORS.warning,
        fields: [field("실행자", actor, true)],
      };
    }

    case "milestone": {
      const milestone = payload.milestone;
      if (!milestone) return null;
      if (payload.action === "edited" && !payload.changes?.due_on) return null;
      if (!new Set(["created", "opened", "closed", "deleted", "edited"]).has(payload.action)) return null;
      return {
        title: `🗓️ 마일스톤 ${payload.action}`,
        description: sanitize(milestone.title, 1500),
        url: milestone.html_url ?? repositoryUrl(payload, env),
        color: payload.action === "closed" ? COLORS.success : COLORS.warning,
        fields: [
          field("목표일", milestone.due_on ? new Date(milestone.due_on).toISOString().slice(0, 10) : "미지정", true),
          field("실행자", actor, true),
        ],
      };
    }

    case "release": {
      if (!new Set(["published", "released", "prereleased"]).has(payload.action)) return null;
      const release = payload.release;
      if (!release) return null;
      return {
        title: `🚀 릴리스 ${payload.action}`,
        description: sanitize(release.name ?? release.tag_name, 1500),
        url: release.html_url,
        color: COLORS.success,
        fields: [field("태그", release.tag_name ?? "-", true), field("실행자", actor, true)],
      };
    }

    case "deployment_status": {
      const state = String(payload.deployment_status?.state ?? "").toLowerCase();
      if (!new Set(["success", "failure", "error"]).has(state)) return null;
      return {
        title: `${state === "success" ? "✅" : "🛑"} 배포 ${state}`,
        description: sanitize(payload.deployment_status?.description ?? payload.deployment?.environment ?? "배포 상태 변경", 1500),
        url: payload.deployment_status?.target_url ?? payload.deployment_status?.environment_url ?? repositoryUrl(payload, env),
        color: state === "success" ? COLORS.success : COLORS.danger,
        fields: [field("환경", payload.deployment?.environment ?? "미지정", true)],
      };
    }

    case "workflow_run": {
      const run = payload.workflow_run;
      const conclusion = String(run?.conclusion ?? "").toLowerCase();
      if (!run || !FAILURE_CONCLUSIONS.has(conclusion)) return null;
      if (String(run.name ?? "").startsWith("Discord GitHub notifications")) return null;
      return {
        title: `🛑 CI ${conclusion}`,
        description: sanitize(run.name, 1500),
        url: run.html_url,
        color: COLORS.danger,
        fields: [field("브랜치", run.head_branch ?? "-", true), field("시도", String(run.run_attempt ?? 1), true)],
      };
    }

    default:
      return null;
  }
}

export function buildSmokeMessage(env = {}) {
  return {
    title: "🧪 GGB GitHub 알림 smoke test",
    description: "Discord webhook 연결과 안전한 메시지 직렬화를 확인했습니다.",
    url: env.GITHUB_REPOSITORY
      ? `${env.GITHUB_SERVER_URL ?? "https://github.com"}/${env.GITHUB_REPOSITORY}/actions`
      : "https://github.com",
    color: COLORS.info,
    fields: [field("모드", env.DRY_RUN === "true" ? "dry-run" : "실제 전송", true)],
  };
}

export function buildDiscordPayload(message, env = {}) {
  const fields = Array.isArray(message.fields) ? message.fields.slice(0, 10) : [];
  return {
    username: "GGB GitHub",
    allowed_mentions: { parse: [] },
    embeds: [
      {
        title: sanitize(message.title, 256) || "GGB GitHub 알림",
        description: sanitize(message.description, 3500) || "상태가 변경됐습니다.",
        url: message.url,
        color: Number(message.color ?? COLORS.neutral),
        fields: fields.map((item) => field(item.name, item.value, Boolean(item.inline))),
        timestamp: new Date(message.timestamp ?? Date.now()).toISOString(),
        footer: { text: sanitize(env.GITHUB_REPOSITORY ?? "GGB", 200) },
      },
    ],
  };
}

export function validateDiscordWebhookUrl(value) {
  if (!value) return false;
  try {
    const url = new URL(value);
    const validHost = url.hostname === "discord.com" || url.hostname === "discordapp.com";
    return url.protocol === "https:" && validHost && /^\/api\/webhooks\/[^/]+\/[^/]+/.test(url.pathname);
  } catch {
    return false;
  }
}

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

export async function postDiscord({ webhookUrl, payload, dryRun = false, fetchImpl = fetch, logger = console }) {
  if (dryRun) {
    logger.log(JSON.stringify(payload, null, 2));
    return { sent: false, dryRun: true };
  }
  if (!validateDiscordWebhookUrl(webhookUrl)) {
    throw new Error("DISCORD_GIT_UPDATES_WEBHOOK is missing or is not a Discord HTTPS webhook URL.");
  }

  const endpoint = new URL(webhookUrl);
  endpoint.searchParams.set("wait", "true");

  for (let attempt = 0; attempt < 3; attempt += 1) {
    let response;
    try {
      response = await fetchImpl(endpoint, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(15_000),
      });
    } catch (error) {
      if (attempt === 2) throw new Error(`Discord webhook network failure: ${error.message}`);
      await wait(1000 * 2 ** attempt);
      continue;
    }

    if (response.ok) return { sent: true, status: response.status };

    if (response.status === 429 && attempt < 2) {
      let retrySeconds = Number(response.headers.get("retry-after") ?? 1);
      try {
        const body = await response.clone().json();
        retrySeconds = Number(body.retry_after ?? retrySeconds);
      } catch {
        // Header value is sufficient when the response is not JSON.
      }
      await wait(Math.min(Math.max(retrySeconds, 0.25), 15) * 1000);
      continue;
    }

    if (response.status >= 500 && attempt < 2) {
      await wait(1000 * 2 ** attempt);
      continue;
    }

    throw new Error(`Discord webhook failed with HTTP ${response.status}.`);
  }

  throw new Error("Discord webhook failed after retrying.");
}

async function githubJson(path, { token, fetchImpl = fetch, method = "GET", body } = {}) {
  if (!token) throw new Error("GITHUB_TOKEN is required for GitHub API reads.");
  const url = path.startsWith("https://") ? path : `https://api.github.com${path}`;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    let response;
    try {
      response = await fetchImpl(url, {
        method,
        headers: {
          accept: "application/vnd.github+json",
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
          "user-agent": "ggb-discord-notifications",
          "x-github-api-version": "2022-11-28",
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(15_000),
      });
    } catch (error) {
      if (attempt === 2) throw new Error(`GitHub API network failure: ${error.message}`);
      await wait(1000 * 2 ** attempt);
      continue;
    }

    if (response.ok) return response.json();

    const retryAfter = Number(response.headers?.get?.("retry-after") ?? 0);
    const retryable = response.status === 429
      || response.status >= 500
      || (response.status === 403 && retryAfter > 0);
    if (retryable && attempt < 2) {
      const seconds = retryAfter > 0 ? retryAfter : 2 ** attempt;
      await wait(Math.min(Math.max(seconds, 0.25), 15) * 1000);
      continue;
    }

    const error = new Error(`GitHub API failed with HTTP ${response.status}.`);
    error.status = response.status;
    throw error;
  }

  throw new Error("GitHub API failed after retrying.");
}

async function githubList(path, options = {}) {
  const items = [];
  const separator = path.includes("?") ? "&" : "?";
  for (let page = 1; page <= 10; page += 1) {
    const chunk = await githubJson(`${path}${separator}per_page=100&page=${page}`, options);
    if (!Array.isArray(chunk)) throw new Error("GitHub list API returned an unexpected payload.");
    items.push(...chunk);
    if (chunk.length < 100) return items;
  }
  throw new Error("GitHub list API exceeded the 1,000-item digest safety limit.");
}

async function mapLimit(items, limit, mapper) {
  const results = new Array(items.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  }
  const workers = Array.from({ length: Math.min(limit, items.length) }, () => worker());
  await Promise.all(workers);
  return results;
}

function isHuman(user) {
  if (!user) return false;
  return user.type !== "Bot" && !String(user.login ?? "").endsWith("[bot]");
}

function withinWindow(dateValue, cutoff) {
  const time = Date.parse(dateValue ?? "");
  return Number.isFinite(time) && time >= cutoff.getTime();
}

export async function collectDailyDigest({ token, repo, now = new Date(), fetchImpl = fetch, logger = console }) {
  if (!repo) throw new Error("GITHUB_REPOSITORY is required for the daily digest.");
  const cutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const encodedRepo = repo.split("/").map(encodeURIComponent).join("/");

  const [branches, issueEvents, issueComments, reviewComments, updatedIssues] = await Promise.all([
    githubList(`/repos/${encodedRepo}/branches`, { token, fetchImpl }),
    githubList(`/repos/${encodedRepo}/issues/events`, { token, fetchImpl }),
    githubList(`/repos/${encodedRepo}/issues/comments?since=${encodeURIComponent(cutoff.toISOString())}`, { token, fetchImpl }),
    githubList(`/repos/${encodedRepo}/pulls/comments?since=${encodeURIComponent(cutoff.toISOString())}&sort=updated&direction=desc`, { token, fetchImpl }),
    githubList(`/repos/${encodedRepo}/issues?state=all&sort=updated&direction=desc&since=${encodeURIComponent(cutoff.toISOString())}`, { token, fetchImpl }),
  ]);

  const workBranches = branches.filter((branch) => !new Set(["develop", "main"]).has(branch.name));
  const comparisons = await mapLimit(
    workBranches,
    4,
    async (branch) => {
      const comparePath = `/repos/${encodedRepo}/compare/${encodeURIComponent("develop")}...${encodeURIComponent(branch.name)}`;
      try {
        return { branch: branch.name, data: await githubJson(comparePath, { token, fetchImpl }) };
      } catch (error) {
        if (error.status === 404) {
          logger.warn(`Skipped deleted branch ${sanitize(branch.name, 100)}.`);
          return null;
        }
        throw error;
      }
    },
  );

  const commitMap = new Map();
  for (const comparison of comparisons.filter(Boolean)) {
    if (Number(comparison.data.ahead_by ?? 0) <= 0) continue;
    for (const commit of comparison.data.commits ?? []) {
      if (!withinWindow(commit.commit?.author?.date ?? commit.commit?.committer?.date, cutoff)) continue;
      if (!commitMap.has(commit.sha)) {
        commitMap.set(commit.sha, {
          branch: comparison.branch,
          sha: commit.sha,
          message: firstLine(commit.commit?.message),
          author: sanitize(commit.author?.login ?? commit.commit?.author?.name ?? "unknown", 100),
          url: commit.html_url,
        });
      }
    }
  }

  const includedIssueEvents = new Set(["assigned", "closed", "demilestoned", "milestoned", "reopened", "unassigned"]);
  const lifecycleChanges = issueEvents
    .filter((event) => includedIssueEvents.has(event.event))
    .filter((event) => withinWindow(event.created_at, cutoff))
    .filter((event) => isHuman(event.actor))
    .map((event) => ({
      number: event.issue?.number,
      title: sanitize(event.issue?.title ?? "제목 없음", 200),
      event: event.event,
      actor: sanitize(event.actor?.login ?? "unknown", 100),
      url: event.issue?.html_url,
    }));

  const openedIssues = updatedIssues
    .filter((issue) => !issue.pull_request)
    .filter((issue) => withinWindow(issue.created_at, cutoff))
    .filter((issue) => isHuman(issue.user))
    .map((issue) => ({
      number: issue.number,
      title: sanitize(issue.title ?? "제목 없음", 200),
      event: "opened",
      actor: sanitize(issue.user?.login ?? "unknown", 100),
      url: issue.html_url,
    }));

  const recentPulls = updatedIssues
    .filter((issue) => issue.pull_request)
    .filter((issue) => withinWindow(issue.updated_at, cutoff));
  const reviewGroups = await mapLimit(recentPulls, 4, async (pull) => {
    const reviews = await githubList(`/repos/${encodedRepo}/pulls/${pull.number}/reviews`, { token, fetchImpl });
    return reviews
      .filter((review) => withinWindow(review.submitted_at, cutoff))
      .filter((review) => isHuman(review.user))
      .filter((review) => !new Set(["PENDING", "CHANGES_REQUESTED"]).has(String(review.state ?? "").toUpperCase()))
      .map((review) => ({
        number: pull.number,
        title: sanitize(pull.title ?? "제목 없음", 200),
        state: sanitize(String(review.state ?? "reviewed").toLowerCase(), 100),
        actor: sanitize(review.user?.login ?? "unknown", 100),
        url: review.html_url ?? pull.html_url,
      }));
  });

  const humanComments = [...issueComments, ...reviewComments]
    .filter((comment) => withinWindow(comment.created_at, cutoff))
    .filter((comment) => isHuman(comment.user))
    .map((comment) => {
      const issueUrl = comment.issue_url ?? comment.pull_request_url;
      const number = Number(String(issueUrl ?? "").split("/").at(-1));
      return {
        number: Number.isFinite(number) ? number : null,
        actor: sanitize(comment.user?.login ?? "unknown", 100),
        url: comment.html_url,
      };
    });

  return {
    repo,
    cutoff: cutoff.toISOString(),
    now: now.toISOString(),
    commits: [...commitMap.values()],
    issueChanges: [...openedIssues, ...lifecycleChanges],
    comments: humanComments,
    reviews: reviewGroups.flat(),
  };
}

function markdownLink(label, url) {
  const safeLabel = sanitize(label, 220).replace(/[\[\]]/g, "");
  return url ? `[${safeLabel}](${url})` : safeLabel;
}

function listField(name, items, formatter, repositoryUrlValue) {
  const visible = items.slice(0, 8).map(formatter);
  if (items.length > visible.length) {
    visible.push(`외 ${items.length - visible.length}건 · ${repositoryUrlValue}`);
  }
  return field(name, visible.join("\n"));
}

export function buildDailyDigestMessage(digest, env = {}) {
  const reviews = digest.reviews ?? [];
  const total = digest.commits.length + digest.issueChanges.length + digest.comments.length + reviews.length;
  if (total === 0) return null;
  const repoUrlValue = `${env.GITHUB_SERVER_URL ?? "https://github.com"}/${digest.repo}`;
  const fields = [];
  if (digest.commits.length > 0) {
    fields.push(
      listField(
        `작업 브랜치 커밋 · ${digest.commits.length}`,
        digest.commits,
        (item) => `• ${markdownLink(`${item.branch} · ${item.message}`, item.url)} · ${item.author}`,
        repoUrlValue,
      ),
    );
  }
  if (digest.issueChanges.length > 0) {
    fields.push(
      listField(
        `Issue 변화 · ${digest.issueChanges.length}`,
        digest.issueChanges,
        (item) => `• ${markdownLink(`#${item.number} ${item.title}`, item.url)} · ${item.event}`,
        repoUrlValue,
      ),
    );
  }
  if (digest.comments.length > 0) {
    fields.push(
      listField(
        `사람 댓글 · ${digest.comments.length}`,
        digest.comments,
        (item) => `• ${markdownLink(`#${item.number ?? "?"} 댓글`, item.url)} · ${item.actor}`,
        repoUrlValue,
      ),
    );
  }
  if (reviews.length > 0) {
    fields.push(
      listField(
        `PR review · ${reviews.length}`,
        reviews,
        (item) => `• ${markdownLink(`#${item.number} ${item.title}`, item.url)} · ${item.state} · ${item.actor}`,
        repoUrlValue,
      ),
    );
  }

  return {
    title: "🧾 GGB GitHub 24시간 요약",
    description: `작업 브랜치·Issue·PR 활동 ${total}건을 요약했습니다. 라벨·설명만 바뀐 항목과 봇 활동은 제외합니다.`,
    url: repoUrlValue,
    color: COLORS.neutral,
    fields,
  };
}

function fieldValue(item, fieldName) {
  for (const node of item.fieldValues?.nodes ?? []) {
    if (node?.field?.name === fieldName) return node.name ?? null;
  }
  return null;
}

export function projectItemsToState(items, repo) {
  const state = {};
  for (const item of items) {
    const content = item.content;
    if (!content?.url || content.repository?.nameWithOwner !== repo) continue;
    state[item.id] = {
      title: sanitize(content.title ?? "제목 없음", 220),
      url: content.url,
      status: fieldValue(item, "Status"),
      priority: fieldValue(item, "우선순위"),
    };
  }
  return state;
}

export function diffCriticalProjectState(previous, current) {
  const changes = [];
  for (const [id, item] of Object.entries(current)) {
    const before = previous[id];
    const reasons = [];
    if ((!before || before.status !== item.status) && item.status === "BLOCKED") reasons.push("BLOCKED");
    if ((!before || before.priority !== item.priority) && new Set(["P0", "P1"]).has(item.priority)) {
      reasons.push(item.priority);
    }
    if (reasons.length > 0) changes.push({ id, ...item, reasons });
  }
  return changes;
}

export function buildProjectMessage(changes, env = {}) {
  if (changes.length === 0) return null;
  const visible = changes.slice(0, 10).map(
    (item) => `• ${markdownLink(item.title, item.url)} · ${item.reasons.join(" + ")}`,
  );
  if (changes.length > visible.length) visible.push(`외 ${changes.length - visible.length}건`);
  return {
    title: "🚨 GGB Project 중요 상태 변경",
    description: visible.join("\n"),
    url: env.PROJECT_URL ?? "https://github.com/users/devb-eru/projects/1",
    color: COLORS.danger,
  };
}

async function fetchProjectItems({ token, owner, number, fetchImpl = fetch }) {
  const query = `
    query($login: String!, $number: Int!, $after: String) {
      user(login: $login) {
        projectV2(number: $number) {
          items(first: 100, after: $after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                ... on Issue { number title url repository { nameWithOwner } }
                ... on PullRequest { number title url repository { nameWithOwner } }
              }
              fieldValues(first: 30) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field { ... on ProjectV2SingleSelectField { name } }
                  }
                }
              }
            }
          }
        }
      }
    }
  `;

  const items = [];
  let after = null;
  do {
    const result = await githubJson("/graphql", {
      token,
      fetchImpl,
      method: "POST",
      body: { query, variables: { login: owner, number: Number(number), after } },
    });
    if (result.errors?.length) throw new Error(`Project GraphQL query failed: ${result.errors[0].message}`);
    const page = result.data?.user?.projectV2?.items;
    if (!page) throw new Error("Project was not found or PROJECTS_READ_TOKEN cannot read it.");
    items.push(...page.nodes);
    after = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
  } while (after);
  return items;
}

async function readJsonFile(path) {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

async function writeJsonFile(path, value) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

async function appendStepSummary(text, env) {
  if (!env.GITHUB_STEP_SUMMARY) return;
  await appendFile(env.GITHUB_STEP_SUMMARY, `${text}\n`, "utf8");
}

async function setOutput(name, value, env) {
  if (!env.GITHUB_OUTPUT) return;
  await appendFile(env.GITHUB_OUTPUT, `${name}=${value}\n`, "utf8");
}

async function sendMessage(message, env) {
  if (!message) return { skipped: true };
  const payload = buildDiscordPayload(message, env);
  return postDiscord({
    webhookUrl: env.DISCORD_WEBHOOK_URL,
    payload,
    dryRun: env.DRY_RUN === "true",
  });
}

export async function runCli(mode, env = process.env) {
  switch (mode) {
    case "event": {
      const payload = JSON.parse(await readFile(env.GITHUB_EVENT_PATH, "utf8"));
      const message = buildImmediateMessage(env.GITHUB_EVENT_NAME, payload, env);
      if (!message) {
        console.log(`Skipped non-critical ${env.GITHUB_EVENT_NAME} event.`);
        await appendStepSummary("### Discord immediate\n\n대상 외 이벤트라 전송하지 않았습니다.", env);
        return;
      }
      const result = await sendMessage(message, env);
      await appendStepSummary(`### Discord immediate\n\n${result.dryRun ? "Dry-run" : "전송"} 완료: ${message.title}`, env);
      return;
    }

    case "smoke": {
      const message = buildSmokeMessage(env);
      const result = await sendMessage(message, env);
      await appendStepSummary(`### Discord smoke test\n\n${result.dryRun ? "Dry-run" : "실제 전송"} 완료`, env);
      return;
    }

    case "digest": {
      const digest = await collectDailyDigest({
        token: env.GITHUB_TOKEN,
        repo: env.GITHUB_REPOSITORY,
      });
      const message = buildDailyDigestMessage(digest, env);
      if (!message) {
        console.log("No digest-worthy changes in the last 24 hours.");
        await appendStepSummary("### Discord 24시간 요약\n\n전송할 변경이 없습니다.", env);
        return;
      }
      const result = await sendMessage(message, env);
      await appendStepSummary(`### Discord 24시간 요약\n\n${result.dryRun ? "Dry-run" : "전송"} 완료`, env);
      return;
    }

    case "project": {
      if (!env.PROJECTS_READ_TOKEN) {
        console.log("PROJECTS_READ_TOKEN is not configured; Project watch is disabled.");
        await appendStepSummary("### Discord Project 감시\n\n`PROJECTS_READ_TOKEN`이 없어 안전하게 건너뛰었습니다.", env);
        return;
      }
      const path = env.PROJECT_STATE_PATH;
      if (!path) throw new Error("PROJECT_STATE_PATH is required for Project watch.");
      const items = await fetchProjectItems({
        token: env.PROJECTS_READ_TOKEN,
        owner: env.PROJECT_OWNER,
        number: env.PROJECT_NUMBER,
      });
      const current = projectItemsToState(items, env.GITHUB_REPOSITORY);
      const previous = await readJsonFile(path);
      const baseline = previous === null;
      const changes = diffCriticalProjectState(previous ?? {}, current);
      const stateChanged = baseline
        || JSON.stringify(Object.entries(previous).sort()) !== JSON.stringify(Object.entries(current).sort());
      const shouldNotifyBaseline = env.NOTIFY_BASELINE === "true";
      const message = baseline && !shouldNotifyBaseline ? null : buildProjectMessage(changes, env);
      if (message) await sendMessage(message, env);
      if (env.DRY_RUN !== "true" && stateChanged) await writeJsonFile(path, current);
      await setOutput("state-changed", String(stateChanged), env);
      const note = baseline && !shouldNotifyBaseline
        ? "최초 상태를 저장했으며 기존 항목은 알리지 않았습니다."
        : changes.length > 0
          ? `${changes.length}건의 중요 변경을 ${env.DRY_RUN === "true" ? "dry-run" : "전송"}했습니다.`
          : "중요 상태 변경이 없습니다.";
      console.log(note);
      await appendStepSummary(`### Discord Project 감시\n\n${note}`, env);
      return;
    }

    default:
      throw new Error(`Unknown mode: ${mode}`);
  }
}

const isDirectRun = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isDirectRun) {
  runCli(process.argv[2]).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
