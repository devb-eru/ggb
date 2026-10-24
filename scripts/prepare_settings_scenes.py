"""Author native Godot settings scenes; run only when rebuilding the initial layout."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
SCENES = ROOT / "game/scenes/ui/settings"
SCENES.mkdir(parents=True, exist_ok=True)
ASSETS = "res://assets/ui/settings/"

def val(v):
    if isinstance(v, bool): return str(v).lower()
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    return str(v)

class Scene:
    def __init__(self): self.lines = ['[gd_scene format=3]', '']; self.resources = {}
    def ext(self, kind, path, key):
        self.lines.insert(2, f'[ext_resource type="{kind}" path="{path}" id="{key}"]')
        self.resources[key] = f'ExtResource("{key}")'
        return self.resources[key]
    def raw(self, s): self.lines += [s, '']
    def node(self, name, kind=None, parent=None, props=None, instance=None):
        attrs = f'name="{name}"'
        if kind: attrs += f' type="{kind}"'
        if parent is not None: attrs += f' parent="{parent}"'
        if instance: attrs += f' instance={instance}'
        self.lines += ['', f'[node {attrs}]']
        for k, v in (props or {}).items():
            self.lines += [f'{k} = {v[1:] if isinstance(v,str) and v.startswith("@") else val(v)}']
    def save(self, name): (SCENES / name).write_text('\n'.join(self.lines) + '\n', encoding='utf-8')

def common(s):
    s.ext('Font', ASSETS+'themes/settings_font.tres', 'font')
    for key in ['option', 'keycap', 'primary', 'bookmark']:
        s.ext('Theme', ASSETS+'themes/'+key+'.tres', key)
    s.ext('Texture2D', ASSETS+'textures/ink_divider.tres', 'rule')
    s.ext('Script', 'res://scripts/ui/settings_choice.gd', 'choice')
    s.ext('StyleBox', ASSETS+'styles/preview_panel.tres', 'preview')
    s.raw('[sub_resource type="StyleBoxEmpty" id="Empty"]')

def text(s, name, parent, ko, en=None, size=30, **props):
    p={'layout_mode':2, 'mouse_filter':2, 'theme_override_fonts/font':'@ExtResource("font")',
       'theme_override_font_sizes/font_size':size, 'text':ko, 'vertical_alignment':1,
       'autowrap_mode':3, 'metadata/ko':ko, 'metadata/en':en or ko}
    p.update(props); s.node(name,'Label',parent,p)

def button(s, name, parent, ko, en=None, kind='option', width=140, height=64, **props):
    p={'layout_mode':2,'custom_minimum_size':f'@Vector2({width}, {height})',
       'theme':'@ExtResource("'+kind+'")','theme_override_fonts/font':'@ExtResource("font")',
       'theme_override_styles/focus':'@SubResource("Empty")', 'theme_override_font_sizes/font_size':28,
       'text':ko, 'autowrap_mode':3, 'metadata/ko':ko,'metadata/en':en or ko,'metadata/scale_minimum':True}
    if kind in ['keycap','primary']:
        for state in ['font_color','font_hover_color','font_focus_color','font_pressed_color','font_hover_pressed_color']:
            p['theme_override_colors/'+state]='@Color(0.96, 0.94, 0.9, 1)'
    p.update(props); s.node(name,'Button',parent,p)

def rule(s,name,parent,height=8):
    s.node(name,'TextureRect',parent,{'layout_mode':2,'custom_minimum_size':f'@Vector2(0, {height})',
      'mouse_filter':2,'texture':'@ExtResource("rule")','expand_mode':1})

def choices(s,parent,name,labels,widths,selected=0):
    s.node(name,'HFlowContainer',parent,{'layout_mode':2,'size_flags_horizontal':3,
      'theme_override_constants/h_separation':0,'theme_override_constants/v_separation':4,
      'script':'@ExtResource("choice")','selected':selected})
    for i, ((ko,en), width) in enumerate(zip(labels,widths)):
        button(s,f'Choice{i}',parent+'/'+name,ko,en,width=width,toggle_mode=True,button_pressed=i==selected)

def field(s,parent,name,ko,en,height=88,label_width=210):
    s.node(name,'HBoxContainer',parent,{'layout_mode':2,'custom_minimum_size':f'@Vector2(0, {height})',
      'theme_override_constants/separation':16})
    text(s,'Caption',parent+'/'+name,ko,en,custom_minimum_size=f'@Vector2({label_width}, 0)',size_flags_vertical=3)

def preview(s,parent,language=False):
    s.node('Preview','PanelContainer',parent,{'layout_mode':2,'custom_minimum_size':'@Vector2(490, 430)',
      'size_flags_horizontal':3,'theme_override_styles/panel':'@ExtResource("preview")'})
    s.node('Margin','MarginContainer',parent+'/Preview',{'layout_mode':2})
    s.node('Body','VBoxContainer',parent+'/Preview/Margin',{'layout_mode':2,
      'alignment':1,'theme_override_constants/separation':36})
    text(s,'Sample',parent+'/Preview/Margin/Body','종이 위쪽에 작은 흠이 있다.'+ ('\n\n수첩에 기록해 두자.' if language else ''),
      size=34,horizontal_alignment=1)
    if not language:
        text(s,'Captions',parent+'/Preview/Margin/Body','[멀리서 종소리가 들린다]',size=28,
          horizontal_alignment=1,**{'theme_override_colors/font_color':'@Color(0.45, 0.41, 0.55, 1)'})

def page_root(s,name,kind='VBoxContainer',height=430):
    s.node(name,kind,props={'layout_mode':3,'anchors_preset':15,'anchor_right':1.0,'anchor_bottom':1.0,
      'custom_minimum_size':f'@Vector2(1220, {height})','size_flags_horizontal':3,
      'theme_override_constants/separation':24})

def accessibility():
    s=Scene(); common(s); page_root(s,'Accessibility','HFlowContainer')
    s.lines += ['theme_override_constants/h_separation = 24','theme_override_constants/v_separation = 24']
    s.node('Fields','VBoxContainer','.',{'layout_mode':2,'custom_minimum_size':'@Vector2(690, 0)','size_flags_horizontal':3,'theme_override_constants/separation':8})
    field(s,'Fields','TextSize','글자 크기','Text size')
    choices(s,'Fields/TextSize','Options',[(t,t) for t in ['100%','125%','150%','200%']],[116]*4)
    rule(s,'Rule1','Fields')
    field(s,'Fields','Signature','단서 표시','Clue display')
    s.node('Options','OptionButton','Fields/Signature',{'layout_mode':2,'size_flags_horizontal':3,
      'custom_minimum_size':'@Vector2(464, 64)','theme_override_fonts/font':'@ExtResource("font")',
      'theme_override_font_sizes/font_size':28,'autowrap_mode':3,'alignment':1,'item_count':3,'selected':0,
      'popup/item_0/text':'색상 + 문양 + 이름','popup/item_1/text':'문양 + 이름','popup/item_2/text':'이름만'})
    rule(s,'Rule2','Fields')
    field(s,'Fields','Motion','화면 움직임','Screen movement')
    choices(s,'Fields/Motion','Options',list(zip(['기본','줄이기','끄기'],['Standard','Reduced','Off'])),[154]*3)
    rule(s,'Rule3','Fields')
    field(s,'Fields','Captions','감각 자막','Sensory captions')
    choices(s,'Fields/Captions','Options',[('켜기','On'),('끄기','Off')],[232]*2)
    preview(s,'.'); s.save('accessibility.tscn')

def display():
    s=Scene(); common(s)
    s.ext('Texture2D',ASSETS+'textures/display_preview.tres','illustration')
    page_root(s,'Display'); s.node('Fields','VBoxContainer','.',{'layout_mode':2,'theme_override_constants/separation':20})
    field(s,'Fields','Mode','화면 모드','Display mode')
    choices(s,'Fields/Mode','Options',list(zip(['창 모드','테두리 없는 전체 화면','전체 화면'],['Windowed','Borderless fullscreen','Fullscreen'])),[280,400,280])
    rule(s,'Rule1','Fields'); field(s,'Fields','Resolution','창 크기','Window size')
    s.node('Options','OptionButton','Fields/Resolution',{'layout_mode':2,'custom_minimum_size':'@Vector2(700, 64)',
      'theme_override_fonts/font':'@ExtResource("font")','theme_override_font_sizes/font_size':30,'autowrap_mode':3,'alignment':1,
      'item_count':5,'selected':0,**{f'popup/item_{i}/text':v for i,v in enumerate(['1280 × 720','1600 × 900','1920 × 1080','2560 × 1440','3840 × 2160'])}})
    s.node('Illustration','TextureRect','.',{'layout_mode':2,'custom_minimum_size':'@Vector2(440, 180)','size_flags_horizontal':4,
      'mouse_filter':2,'texture':'@ExtResource("illustration")','expand_mode':1,'stretch_mode':5})
    s.save('display.tscn')

def audio():
    s=Scene(); common(s); page_root(s,'Audio')
    s.lines.append('theme_override_constants/separation = 4')
    for i,(id,ko,en) in enumerate([('Master','전체 음량','Master volume'),('Bgm','배경 음악','Music'),('Ambience','공간음','Ambience'),('Effects','효과음','Sound effects')]):
        s.node(id,'HBoxContainer','.',{'layout_mode':2,'custom_minimum_size':'@Vector2(0, 64)',
          'theme_override_constants/separation':16})
        text(s,'Caption',id,ko,en,custom_minimum_size='@Vector2(210, 0)')
        s.node('Slider','HSlider',id,{'layout_mode':2,'size_flags_horizontal':3,
          'custom_minimum_size':'@Vector2(0, 64)','max_value':100.0,'step':1.0,'value':100.0})
        text(s,'Value',id,'100%',size=30,custom_minimum_size='@Vector2(100, 0)',horizontal_alignment=2)
        rule(s,'Rule'+str(i),'.')
    field(s,'.','Mute','전체 음소거','Mute all')
    choices(s,'Mute','Options',[('켜기','On'),('끄기','Off')],[232]*2,1)
    s.save('audio.tscn')

def controls():
    s=Scene(); common(s); page_root(s,'Controls','HFlowContainer')
    s.lines += ['theme_override_constants/h_separation = 24','theme_override_constants/v_separation = 24']
    s.node('Left','VBoxContainer','.',{'layout_mode':2,'custom_minimum_size':'@Vector2(600, 0)','size_flags_horizontal':3,'theme_override_constants/separation':6})
    s.node('Divider','ColorRect','.',{'layout_mode':2,'custom_minimum_size':'@Vector2(1, 0)',
      'mouse_filter':2,'color':'@Color(0.48, 0.43, 0.60, 0.65)'})
    s.node('Right','VBoxContainer','.',{'layout_mode':2,'custom_minimum_size':'@Vector2(570, 0)','size_flags_horizontal':3,'theme_override_constants/separation':6})
    groups=[('Left',[('confirm','선택 / 상호작용','Confirm / interact',[('Enter','confirm'),('Space','confirm_alt')]),
      ('cancel','취소 / 메뉴','Cancel / menu',[('Esc','cancel')]),('notebook','수첩','Notebook',[('N','notebook')]),
      ('inventory','소지품','Inventory',[('I','inventory')]),('movement','항목 이동','Move focus',[('↑','up'),('↓','down'),('←','left'),('→','right')])]),
      ('Right',[('next','다음 항목','Next item',[('Tab','next')]),('previous','이전 항목','Previous item',[('Shift + Tab','previous')]),
       ('page_up','이전 페이지','Previous page',[('Page Up','page_up')]),('page_down','다음 페이지','Next page',[('Page Down','page_down')])])]
    for col,rows in groups:
        for id,ko,en,keys in rows:
            field(s,col,id,ko,en,68,245 if col=='Left' else 210)
            s.node('Keys','HFlowContainer',col+'/'+id,{'layout_mode':2,'size_flags_horizontal':3,
              'theme_override_constants/h_separation':10,'theme_override_constants/v_separation':8})
            for caption,key in keys:
                button(s,'Key_'+key,col+'/'+id+'/Keys',caption,kind='keycap',width=76 if id=='movement' else (240 if col=='Right' else 140),toggle_mode=True,
                  **{f'theme_override_colors/{k}':'@Color(0.96, 0.94, 0.9, 1)' for k in ['font_color','font_hover_color','font_focus_color','font_pressed_color']})
            rule(s,'Rule_'+id,col)
    s.save('controls.tscn')

def language():
    s=Scene();common(s)
    s.ext('StyleBox',ASSETS+'styles/radio_checked.tres','checked')
    s.ext('StyleBox',ASSETS+'styles/radio_unchecked.tres','unchecked')
    page_root(s,'Language','HBoxContainer')
    s.node('Languages','HFlowContainer','.',{'layout_mode':2,'size_flags_horizontal':3,
      'custom_minimum_size':'@Vector2(650, 0)','theme_override_constants/v_separation':24,
      'script':'@ExtResource("choice")','selected':0})
    for i,name in enumerate(['Korean','English']):
        button(s,name,'Languages','',width=650,height=100,toggle_mode=True,button_pressed=i==0,**{'metadata/scale_width':False})
        s.node('Radio','Panel','Languages/'+name,{'layout_mode':1,'anchor_top':0.5,'anchor_bottom':0.5,
          'offset_left':38.0,'offset_right':70.0,'offset_top':-16.0,'offset_bottom':16.0,'mouse_filter':2,
          'theme_override_styles/panel':'@ExtResource("checked")' if i==0 else '@ExtResource("unchecked")'})
        text(s,'Caption','Languages/'+name,'한국어' if i==0 else 'English',size=38,
          layout_mode=1,anchor_right=1.0,anchor_bottom=1.0,offset_left=100.0,offset_right=-28.0,
          **{'theme_override_colors/font_color':'@Color(0.12, 0.12, 0.24, 1)'})
    preview(s,'.',True);s.save('language.tscn')

def confirmation():
    s=Scene();common(s)
    s.ext('StyleBox',ASSETS+'styles/confirmation_panel.tres','paper')
    s.node('Confirmation','Control',props={'layout_mode':3,'anchors_preset':15,'anchor_right':1.0,'anchor_bottom':1.0})
    s.node('Dimmer','ColorRect','.',{'layout_mode':1,'anchor_right':1.0,'anchor_bottom':1.0,'color':'@Color(0.04, 0.03, 0.12, 0.23)'})
    s.node('Center','CenterContainer','.',{'layout_mode':1,'anchor_top':0.42,'anchor_right':1.0,'anchor_bottom':1.0})
    s.node('Paper','PanelContainer','Center',{'layout_mode':2,'custom_minimum_size':'@Vector2(760, 300)',
      'theme_override_styles/panel':'@ExtResource("paper")'})
    s.node('Margin','MarginContainer','Center/Paper',{'layout_mode':2})
    s.node('Body','VBoxContainer','Center/Paper/Margin',{'layout_mode':2,'theme_override_constants/separation':16})
    text(s,'Title','Center/Paper/Margin/Body','이 화면을 유지할까요?','Keep this display?',size=36,horizontal_alignment=1,**{'metadata/chrome':True})
    rule(s,'Rule','Center/Paper/Margin/Body')
    text(s,'Countdown','Center/Paper/Margin/Body','15초 뒤 이전 설정으로 돌아갑니다.','Previous settings return in 15 seconds.',size=28,horizontal_alignment=1)
    s.node('Buttons','HBoxContainer','Center/Paper/Margin/Body',{'layout_mode':2,'alignment':1,'theme_override_constants/separation':24})
    button(s,'Revert','Center/Paper/Margin/Body/Buttons','되돌리기','Revert',width=240)
    button(s,'Keep','Center/Paper/Margin/Body/Buttons','유지','Keep',width=240,toggle_mode=True,button_pressed=True)
    s.save('display_confirmation.tscn')

def screen():
    s=Scene();common(s)
    for id in ['menu_background','settings_paper','close_icon']:
        s.ext('Texture2D',ASSETS+'textures/'+id+'.tres',id)
    s.ext('Theme',ASSETS+'themes/settings_runtime.tres','theme')
    s.ext('Script','res://scripts/ui/settings_screen.gd','script')
    for id in ['accessibility','display','audio','controls','language','display_confirmation']:
        s.ext('PackedScene','res://scenes/ui/settings/'+id+'.tscn',id)
    s.node('SettingsScreen','PanelContainer',props={'layout_mode':3,'anchors_preset':15,'anchor_right':1.0,'anchor_bottom':1.0,
      'theme':'@ExtResource("theme")','theme_override_styles/panel':'@SubResource("Empty")','script':'@ExtResource("script")'})
    s.node('Surface','Control','.',{'layout_mode':2})
    for name,tex,rect in [('Background','menu_background',(0,0,1,1)),('Paper','settings_paper',(.085,.032,.925,.947))]:
        s.node(name,'TextureRect','Surface',{'layout_mode':1,'anchor_left':rect[0],'anchor_top':rect[1],
          'anchor_right':rect[2],'anchor_bottom':rect[3],'mouse_filter':2,'texture':'@ExtResource("'+tex+'")',
          'expand_mode':1,'stretch_mode':6 if name=='Background' else 0})
    text(s,'Title','Surface','설정','Settings',size=64,layout_mode=1,anchor_left=.32,anchor_right=.72,
      anchor_top=.09,anchor_bottom=.18,horizontal_alignment=1,**{'metadata/chrome':True})
    for name,y in [('HeaderRule',.198),('FooterRule',.756)]:
        s.node(name,'TextureRect','Surface',{'layout_mode':1,'anchor_left':.205,'anchor_right':.86,'anchor_top':y,
          'offset_bottom':22.0,'anchor_bottom':y,'mouse_filter':2,'texture':'@ExtResource("rule")','expand_mode':1})
    button(s,'Close','Surface','',width=56,height=56,layout_mode=1,anchor_left=.84,anchor_top=.115,
      anchor_right=.84,anchor_bottom=.115,offset_right=56.0,offset_bottom=56.0,
      icon='@ExtResource("close_icon")',expand_icon=True,**{'theme_override_constants/icon_max_width':40,
       'theme_override_styles/normal':'@SubResource("Empty")','theme_override_styles/hover':'@SubResource("Empty")',
       'theme_override_styles/pressed':'@SubResource("Empty")','metadata/chrome':True})
    s.node('Tabs','VBoxContainer','Surface',{'layout_mode':1,'anchor_left':.055,'anchor_top':.22,'anchor_right':.19,
      'anchor_bottom':.74,'theme_override_constants/separation':12})
    for i,(id,ko,en) in enumerate([('Accessibility','접근성','Accessibility'),('Display','화면','Display'),('Audio','소리','Audio'),('Controls','조작','Controls'),('Language','언어','Language')]):
        button(s,id,'Surface/Tabs','',kind='bookmark',width=240,height=94,toggle_mode=True,button_pressed=i==0,
          **{'metadata/chrome':True,'metadata/scale_minimum':False})
        text(s,'Caption','Surface/Tabs/'+id,ko,en,layout_mode=1,anchor_right=1.0,anchor_bottom=1.0,
          offset_left=58.0,offset_right=-16.0,horizontal_alignment=1,
          **{'theme_override_colors/font_color':'@Color(0.96, 0.94, 0.9, 1)','metadata/chrome':True,'metadata/fixed_scale':True})
    text(s,'Category','Surface','접근성','Accessibility',size=46,layout_mode=1,anchor_left=.215,
      anchor_right=.85,anchor_top=.24,anchor_bottom=.306,**{'metadata/chrome':True})
    s.node('ContentScroll','ScrollContainer','Surface',{'layout_mode':1,'anchor_left':.215,'anchor_right':.86,
      'anchor_top':.33,'anchor_bottom':.74,'horizontal_scroll_mode':0,'follow_focus':True})
    s.node('Pages','VBoxContainer','Surface/ContentScroll',{'layout_mode':2,'size_flags_horizontal':3})
    for id in ['accessibility','display','audio','controls','language']:
        s.node(id.capitalize(),parent='Surface/ContentScroll/Pages',instance=s.resources[id],props={'layout_mode':2,'visible':id=='accessibility'})
    text(s,'Message','Surface','','',size=25,layout_mode=1,anchor_left=.215,anchor_right=.60,
      anchor_top=.777,anchor_bottom=.945,**{'theme_override_colors/font_color':'@Color(0.48, 0.20, 0.32, 1)'})
    button(s,'Defaults','Surface','기본값','Defaults',width=180,height=70,layout_mode=1,anchor_left=.26,
      anchor_top=.795,anchor_right=.26,anchor_bottom=.795,offset_right=180.0,offset_bottom=70.0,
      **{'metadata/chrome':True,'metadata/scale_minimum':False,'theme_override_styles/normal':'@SubResource("Empty")',
       'theme_override_styles/hover':'@SubResource("Empty")','theme_override_styles/pressed':'@SubResource("Empty")'})
    button(s,'Back','Surface','뒤로','Back',width=140,height=90,layout_mode=1,anchor_left=.61,anchor_right=.61,
      anchor_top=.795,anchor_bottom=.795,offset_right=140.0,offset_bottom=90.0,
      **{'metadata/chrome':True,'metadata/scale_minimum':False,'theme_override_styles/normal':'@SubResource("Empty")',
       'theme_override_styles/hover':'@SubResource("Empty")','theme_override_styles/pressed':'@SubResource("Empty")'})
    button(s,'Apply','Surface','적용','Apply',kind='primary',width=310,height=90,layout_mode=1,anchor_left=.70,
      anchor_right=.70,anchor_top=.795,anchor_bottom=.795,offset_right=310.0,offset_bottom=90.0,
      **{'metadata/chrome':True,'metadata/scale_minimum':False})
    button(s,'CancelCapture','Surface','키 입력 취소','Cancel capture',width=310,height=90,layout_mode=1,
      anchor_left=.70,anchor_right=.70,anchor_top=.795,anchor_bottom=.795,offset_right=310.0,offset_bottom=90.0,
      visible=False,**{'metadata/chrome':True,'metadata/scale_minimum':False})
    s.node('Confirmation',parent='.',instance=s.resources['display_confirmation'],props={'layout_mode':2,'visible':False})
    for id in ['Accessibility','Display','Audio','Controls','Language']:
        s.raw(f'[editable path="Surface/ContentScroll/Pages/{id}"]')
    s.save('settings_screen.tscn')

def resources():
    themes=ROOT/'game/assets/ui/settings/themes'; styles=ROOT/'game/assets/ui/settings/styles'
    (themes/'settings_font.tres').write_text('[gd_resource type="SystemFont" format=3]\n[resource]\nfont_names = PackedStringArray("Batang", "Georgia", "serif")\n',encoding='utf-8')
    for kind,texture,inset in [('preview','preview_paper',32),('confirmation','confirmation_paper',36)]:
        (styles/(kind+'_panel.tres')).write_text(f'[gd_resource type="StyleBoxTexture" format=3]\n[ext_resource type="Texture2D" path="{ASSETS}textures/{texture}.tres" id="1"]\n[resource]\ntexture = ExtResource("1")\n'+''.join(f'content_margin_{side} = {inset}.0\n' for side in ['left','right','top','bottom']),encoding='utf-8')
    r=['[gd_resource type="Theme" format=3]',f'[ext_resource type="Font" path="{ASSETS}themes/settings_font.tres" id="font"]']
    for state in ['normal','hover','pressed','disabled']:
        r.append(f'[ext_resource type="StyleBox" path="{ASSETS}styles/option_{state}.tres" id="{state}"]')
    for id in ['slider_track','slider_fill']:
        original=(styles/(id+'.tres')).read_text(encoding='utf-8')
        (styles/(id+'_native.tres')).write_text(original+'\ncontent_margin_top = 4.0\ncontent_margin_bottom = 4.0\n',encoding='utf-8')
        r.append(f'[ext_resource type="StyleBox" path="{ASSETS}styles/{id}_native.tres" id="{id}"]')
    r += [f'[ext_resource type="Texture2D" path="{ASSETS}textures/slider_grabber.res" id="grabber"]',
      '[sub_resource type="StyleBoxEmpty" id="Empty"]','[resource]','default_font = ExtResource("font")','default_font_size = 30']
    for kind in ['Label','Button','OptionButton','PopupMenu']:
        for color in ['font_color','font_hover_color','font_focus_color','font_pressed_color','font_hover_pressed_color']:
            r.append(f'{kind}/colors/{color} = Color(0.12, 0.12, 0.24, 1)')
    r.append('OptionButton/colors/font_disabled_color = Color(0.40, 0.39, 0.49, 1)')
    for state in ['normal','hover','pressed','disabled']: r.append(f'OptionButton/styles/{state} = ExtResource("{state}")')
    for kind in ['OptionButton','ScrollContainer','HSlider']: r.append(f'{kind}/styles/focus = SubResource("Empty")')
    r += ['OptionButton/constants/modulate_arrow = 1','OptionButton/constants/outline_size = 0',
      'HSlider/styles/slider = ExtResource("slider_track")','HSlider/styles/grabber_area = ExtResource("slider_fill")',
      'HSlider/styles/grabber_area_highlight = ExtResource("slider_fill")','HSlider/icons/grabber = ExtResource("grabber")',
      'HSlider/icons/grabber_highlight = ExtResource("grabber")','HSlider/icons/grabber_disabled = ExtResource("grabber")']
    (themes/'settings_runtime.tres').write_text('\n'.join(r)+'\n',encoding='utf-8')

if __name__=='__main__':
    resources()
    for build in [accessibility,display,audio,controls,language,confirmation,screen]: build()
    print('Authored settings screen, five pages and display confirmation.')
