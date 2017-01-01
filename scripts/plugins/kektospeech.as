bool arpamode = true;

class Phoneme
{
	string soundFile;  // path to the sound clip
	string code;       // how this sound appears as text ("ch", "aa")
	int pitch;
	float len; // length of the sound
	
	Phoneme() {
		pitch = 100;
	}
	
	Phoneme(string codetxt)
	{
		if (!arpamode)
			soundFile = "texttospeech/tremogg/" + codetxt + ".ogg";
		else
			soundFile = "texttospeech/arpa/" + codetxt + ".wav";
		code = codetxt;
		pitch = 100;
		len = arpaLen(codetxt);
	}
	
	Phoneme(string codetxt, int ipitch, float flen)
	{
		if (!arpamode)
			soundFile = "texttospeech/tremogg/" + codetxt + ".ogg";
		else
			soundFile = "texttospeech/arpa/" + codetxt + ".wav";
		code = codetxt;
		pitch = ipitch;
		len = flen;
	}
}

class PlayerState
{
	CTextMenu@ menu;
	string talker_id;  // voice this player is using
	int pitch; 		   // voice pitch adjustment (100 = normal, range = 1-1000)
	
	void initMenu(CBasePlayer@ plr, TextMenuPlayerSlotCallback@ callback, bool destroyOldMenu)
	{
		destroyOldMenu = false; // Unregistering throws an error for whatever reason. TODO: Ask the big man why
		if (destroyOldMenu and @menu !is null and menu.IsRegistered()) {
			menu.Unregister();
			@menu = null;
		}
		CTextMenu temp(@callback);
		@menu = @temp;
	}
	
	void openMenu(CBasePlayer@ plr) 
	{
		if ( menu.Register() == false ) {
			g_Game.AlertMessage( at_console, "Oh dear menu registration failed\n");
		}
		menu.Open(10, 0, plr);
	}
}

// All possible sound channels we can use
array<SOUND_CHANNEL> channels = {CHAN_STATIC, CHAN_VOICE, CHAN_STREAM, CHAN_BODY, CHAN_ITEM, CHAN_NETWORKVOICE_BASE, CHAN_AUTO, CHAN_WEAPON};
dictionary player_states; // persistent-ish player data, organized by steam-id or username if on a LAN server, values are @PlayerState
array<Phoneme@> g_all_phonemes; // for straight-forward precaching, duplicates the data in g_talkers
dictionary g_phonemes;
dictionary english;
dictionary arpamap;
dictionary lettermap;
string default_voice = "";

void print(string text) { g_Game.AlertMessage( at_console, "VoiceCommands: " + text); }
void println(string text) { print(text + "\n"); }
void printSuccess() { g_Game.AlertMessage( at_console, "SUCCESS\n"); }

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "w00tguy123 - forums.svencoop.com" );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );	
	g_Hooks.RegisterHook( Hooks::Game::MapChange, @MapChange );
		
	loadArpaMap();
	loadLetterMap();
	loadVoiceData();
	loadEnglishWords();
}

void MapInit()
{
	g_Game.AlertMessage( at_console, "Precaching " + g_all_phonemes.length() + " sounds\n");
	
	for (uint i = 0; i < g_all_phonemes.length(); i++) {
		g_SoundSystem.PrecacheSound(g_all_phonemes[i].soundFile);
		g_Game.PrecacheGeneric("sound/" + g_all_phonemes[i].soundFile);
	}
}

HookReturnCode MapChange()
{
	// set all menus to null. Apparently this fixes crashes for some people:
	// http://forums.svencoop.com/showthread.php/43310-Need-help-with-text-menu#post515087
	array<string>@ stateKeys = player_states.getKeys();
	for (uint i = 0; i < stateKeys.length(); i++)
	{
		PlayerState@ state = cast<PlayerState@>( player_states[stateKeys[i]] );
		if (state.menu !is null)
			@state.menu = null;
	}
	return HOOK_CONTINUE;
}

enum parse_mode {
	PARSE_SETTINGS,
	PARSE_VOICES,
	PARSE_CMDS_1,
	PARSE_CMDS_2,
	PARSE_SPECIAL_CMDS,
}

void loadArpaMap() {

	// 1-to-1 map from arpabet
	arpamap['aa'] = 'ah';
	arpamap['ae'] = 'aah';
	arpamap['ah'] = 'uh';
	arpamap['ao'] = 'ah oh'; // ??
	arpamap['aw'] = 'ao';
	arpamap['ay'] = 'i';
	arpamap['ch'] = 'ch';
	arpamap['dh'] = 'th';
	arpamap['eh'] = 'eh';
	arpamap['er'] = 'er';
	arpamap['ey'] = 'ae';
	arpamap['ih'] = 'ih';
	arpamap['iy'] = 'ee';
	arpamap['ow'] = 'oh';
	arpamap['oy'] = 'oi';
	arpamap['th'] = 'th';
	arpamap['uh'] = 'u'; // ??
	arpamap['uw'] = 'u';
	arpamap['n'] = 'nn';
	arpamap['t'] = 'tt';
	arpamap['z'] = 'zz';
	arpamap['k'] = 'kk';
	arpamap['s'] = 'ss';
	arpamap['l'] = 'll';
	arpamap['v'] = 'vv';
	arpamap['d'] = 'dih'; // ??
	arpamap['r'] = 'rr';
	arpamap['m'] = 'mm';
	arpamap['p'] = 'puh'; // ??
	arpamap['g'] = 'guh'; // ??
	arpamap['b'] = 'buh'; // ??
	arpamap['zh'] = 'ssh'; // ????
	arpamap['jh'] = 'jyeh'; // ????
	arpamap['hh'] = 'huh'; // ???? Should be supert short??
	arpamap['f'] = 'fuh'; // ???
	arpamap['ssh'] = 'ssh'; // wow
	arpamap['waa'] = 'wa';
	arpamap['wiy'] = 'wi';
	arpamap['way'] = 'wa i'; // Theres no "wai" ???
	arpamap['rao'] = 'ra';
	arpamap['may'] = 'mai';
	arpamap['taa'] = 'ta';
	arpamap['day'] = 'dai';
	arpamap['y'] = 'ee'; // works for all words?
	arpamap['w'] = 'wuh'; // ??
	
	
	// combinations of arpabet
	arpamap['kl'] = 'kll';
	arpamap['mey'] = 'mae';
	arpamap['shah'] = 'shaah';
	arpamap['poy'] = 'poi';
	arpamap['wow'] = 'wo';
	arpamap['dah'] = 'duh';
	arpamap['bah'] = 'ba';
	arpamap['ts'] = 'ts';
	arpamap['hhae'] = 'haah';
	arpamap['maa'] = 'muh';
	arpamap['paw'] = 'pa';
	arpamap['say'] = 'sai';
	arpamap['shaa'] = 'sha';
	arpamap['ps'] = 'ps';
	arpamap['per'] = 'per';
	arpamap['seh'] = 'seh';
	arpamap['sae'] = 'saah';
	arpamap['low'] = 'loh';
	arpamap['paa'] = 'pa';
	arpamap['st'] = 'st';
	arpamap['rah'] = 'ruh';
	arpamap['fiy'] = 'fi';
	arpamap['baw'] = 'fi';
	arpamap['kah'] = 'kuh';
	arpamap['kao'] = 'ka oh';
	arpamap['kyuw'] = 'kyu';
	arpamap['dih'] = 'dih';
	arpamap['fr'] = 'frr';
	arpamap['kow'] = 'koh';
	arpamap['geh'] = 'gae';
	arpamap['key'] = 'kae';
	arpamap['sih'] = 'sih'; // ??
	arpamap['ng'] = 'ing'; // PROBABLY DOESN'T WORK FOR ALL WORDS
	arpamap['gah'] = 'guh';
	arpamap['tih'] = 'tih';
	arpamap['wah'] = 'wuh';
	arpamap['siy'] = 'si';
	arpamap['dhah'] = 'the';
	arpamap['ray'] = 'rai';
	arpamap['peh'] = 'peh';
	arpamap['pl'] = 'pll';
	arpamap['kaa'] = 'ka';
	arpamap['mah'] = 'muh';
	arpamap['dae'] = 'daah';
	arpamap['sh'] = 'ssh';
	arpamap['hhay'] = 'hai';
	arpamap['fah'] = 'fuh';
	arpamap['lih'] = 'lih';
	arpamap['deh'] = 'deh';
	arpamap['sah'] = 'suh';
	arpamap['daa'] = 'da';
	arpamap['daa'] = 'da';
	arpamap['fuh'] = 'fu'; // ??
	arpamap['pih'] = 'pih';
	arpamap['riy'] = 'ri';
	arpamap['sl'] = 'sll';
	arpamap['diy'] = 'di';
	arpamap['lah'] = 'luh';
	arpamap['miy'] = 'mi';
	arpamap['weh'] = 'weh';
	arpamap['sch'] = 'ssh'; // PROBABLY DOESN'T WORK FOR ALL WORDS
	arpamap['fao'] = 'fah oh'; // ??
	arpamap['tuw'] = 'tu';
	arpamap['tr'] = 'trr';
	arpamap['pah'] = 'puh';
	arpamap['ley'] = 'lae';
	arpamap['ber'] = 'brr';
	arpamap['liy'] = 'li';
	arpamap['vaa'] = 'va';
	arpamap['tiy'] = 'ti';
	arpamap['biy'] = 'bi';
	arpamap['baa'] = 'ba';
	arpamap['bae'] = 'baah';
	arpamap['beh'] = 'beh';
	arpamap['kih'] = 'kih';
	arpamap['tow'] = 'to';
	arpamap['bey'] = 'bae';
	arpamap['yah'] = 'yuh';
	arpamap['dow'] = 'doh';
	arpamap['hhaw'] = 'ha oh'; // ??
	arpamap['vih'] = 'vv ih'; //?
	arpamap['bih'] = 'bih';
	arpamap['taw'] = 'ta oh';
	arpamap['buw'] = 'bu';
	arpamap['br'] = 'brr';
	arpamap['viy'] = 'vv ee';
	arpamap['ziy'] = 'zz ee';
	arpamap['teh'] = 'teh';
	arpamap['tah'] = 'tuh';
	arpamap['tah'] = 'tuh';
	arpamap['ner'] = 'ner';
	arpamap['ter'] = 'trr';
	arpamap['duw'] = 'du';
	arpamap['ler'] = 'lrr';
	arpamap['dr'] = 'drr';
	arpamap['raa'] = 'rah';
	arpamap['fer'] = 'frr';
	arpamap['mih'] = 'mih';
	arpamap['hhao'] = 'ha';
	arpamap['bay'] = 'bai';
	arpamap['jhaa'] = 'ja';
	arpamap['gey'] = 'geh';
	arpamap['meh'] = 'meh';
	arpamap['jheh'] = 'jeh';
	arpamap['bl'] = 'bl';
	arpamap['neh'] = 'neh';
	arpamap['niy'] = 'ni';
	arpamap['nao'] = 'na';
	arpamap['mae'] = 'maah';
	arpamap['bow'] = 'boh';
	arpamap['bao'] = 'ba oh';
	arpamap['hhah'] = 'huh';
	arpamap['shih'] = 'ssh ih';
	arpamap['zah'] = 'zuh';
	arpamap['jhah'] = 'jyah';
	arpamap['fey'] = 'fae';
	arpamap['hhaa'] = 'ha';
	arpamap['hhey'] = 'hae';
	arpamap['chih'] = 'ch ih';
	arpamap['mow'] = 'moh';
	arpamap['wih'] = 'wuh ih'; // ?????
	arpamap['zih'] = 'zz ih'; // ??
	arpamap['gow'] = 'goh';
	arpamap['jhih'] = 'jyeh'; // ??
	arpamap['nah'] = 'nuh';
	arpamap['zow'] = 'zoh';
	arpamap['saa'] = 'sa';
	arpamap['kae'] = 'kk aah'; // ??
	arpamap['sher'] = 'ssh er';
	arpamap['shiy'] = 'shi';
	arpamap['shay'] = 'ssh i';
	arpamap['sow'] = 'soh';
	arpamap['luw'] = 'lu';
	arpamap['zaa'] = 'za';
	arpamap['zao'] = 'za';
	arpamap['rae'] = 'raah';
	arpamap['ruw'] = 'ru';
	arpamap['ser'] = 'srr';
	arpamap['byuw'] = 'byu';
	arpamap['lae'] = 'la';
	arpamap['buh'] = 'bu'; // ???
	arpamap['zer'] = 'zz er';
	arpamap['pow'] = 'pull'; // THERES NO "PO" ????
	arpamap['puh'] = 'pu'; 
	arpamap['eriy'] = 'er ee';
	arpamap['kiy'] = 'ki';
	arpamap['dey'] = 'dae';
	arpamap['nih'] = 'nih';
	arpamap['kaw'] = 'ka oh'; // ??
	arpamap['kuw'] = 'ku';
	arpamap['reh'] = 'reh';
	arpamap['tey'] = 'tae';
	arpamap['hheh'] = 'heh';
	arpamap['kyer'] = 'kyeh er'; // ????
	arpamap['kuh'] = 'ku'; // ???
	arpamap['kyah'] = 'kyu'; // ???? Should be KYUHH?
	arpamap['zey'] = 'zz ae'; // ????
	arpamap['tao'] = 'ta';
	arpamap['row'] = 'roh';
	arpamap['rih'] = 'rih';
	arpamap['vey'] = 'vae';
	arpamap['gao'] = 'ga';
	arpamap['sey'] = 'sae';
	arpamap['veh'] = 'veh';
	arpamap['vah'] = 'vuh';
	arpamap['ver'] = 'vrr';
	arpamap['fay'] = 'fai';
	arpamap['duh'] = 'du'; // ???
	arpamap['now'] = 'no';
	arpamap['naa'] = 'na';
	arpamap['lay'] = 'lai';
	arpamap['wey'] = 'wae';
	arpamap['chah'] = 'ch uh';
	arpamap['chuw'] = 'chu';
	arpamap['yuw'] = 'yu';
	arpamap['cher'] = 'ch er';
	arpamap['chae'] = 'ch aah';
	arpamap['der'] = 'drr';
	arpamap['laa'] = 'la';
	arpamap['ger'] = 'grr';
	arpamap['vay'] = 'vai';
	arpamap['hhow'] = 'ho';
	arpamap['jher'] = 'jyeh er';
	arpamap['hhih'] = 'heh ih'; // ??
	arpamap['hhiy'] = 'hai';
	arpamap['jhey'] = 'jae';
	arpamap['jhoy'] = 'jo oi'; // speed up
	arpamap['jhuw'] = 'ju';
	arpamap['lao'] = 'la';
	arpamap['rey'] = 'rae';
	arpamap['mer'] = 'mrr';
	arpamap['mao'] = 'ma';
	arpamap['leh'] = 'leh';
	arpamap['fow'] = 'foh';
	arpamap['dao'] = 'da';
	arpamap['hhuh'] = 'hu'; // bad
	arpamap['keh'] = 'keh';
	arpamap['vae'] = 'vah';
	arpamap['tay'] = 'tai';
	arpamap['vow'] = 'voh';
	arpamap['jhiy'] = 'ji';
	arpamap['luh'] = 'lu';
	arpamap['gaa'] = 'ga';
	arpamap['tae'] = 'taah';
	arpamap['fl'] = 'fll';
	arpamap['pey'] = 'pae';
	arpamap['thah'] = 'thuh';
	arpamap['thiy'] = 'th ee'; // ?
	arpamap['theh'] = 'th eh';
	arpamap['faa'] = 'fa';
	arpamap['feh'] = 'feh';
	arpamap['fih'] = 'fih';
	arpamap['gae'] = 'ga'; // not quite gah
	arpamap['thaa'] = 'th ah'; // "tha" broken
	arpamap['faw'] = 'fa oh'; // mb fah oh?
	arpamap['shey'] = 'ssh ae';
	arpamap['wer'] = 'wrr';
	arpamap['fuw'] = 'fu';
	arpamap['baw'] = 'ba ao';
	arpamap['giy'] = 'gi';
	arpamap['gr'] = 'grr'; // maybe split up?
	arpamap['gih'] = 'gih';
	arpamap['nuw'] = 'nu';
	arpamap['guw'] = 'gu';
	arpamap['sao'] = 'sa';
	arpamap['fy'] = 'fi'; // split up?
	arpamap['hher'] = 'heh er'; // ??
	arpamap['muw'] = 'mu';
	arpamap['hhoy'] = 'ho oi'; //?
	arpamap['hhuw'] = 'hu';
	arpamap['pae'] = 'paah';
	arpamap['foy'] = 'foh oi'; // ?
	arpamap['pao'] = 'pa';
	arpamap['sheh'] = 'ssh eh'; 
	arpamap['piy'] = 'pi'; 
	arpamap['vao'] = 'va'; 
	arpamap['jhae'] = 'ja'; 
	arpamap['kay'] = 'kai'; 
	arpamap['yaa'] = 'ya'; 
	arpamap['kyaa'] = 'kyah';
	arpamap['nae'] = 'naah';
	arpamap['ney'] = 'nae';
	arpamap['nay'] = 'nai';
	arpamap['naw'] = 'nao'; // wow only one that does "AW" correctly
	arpamap['noy'] = 'no oi'; // ?
	arpamap['cheh'] = 'cheh';
	arpamap['chiy'] = 'chi';
	arpamap['yow'] = 'yoh';
	arpamap['zae'] = 'zah';
	arpamap['fae'] = 'fah';
	arpamap['loy'] = 'loh oi'; // ?
	arpamap['law'] = 'la oh';
	arpamap['wuh'] = 'wuh'; // no "WU" ??
	arpamap['gay'] = 'gai';
	arpamap['guh'] = 'gu';
	arpamap['pay'] = 'pai';
	arpamap['muh'] = 'mu'; // ?
	arpamap['they'] = 'they';
	arpamap['ther'] = 'th er'; // ?
	arpamap['thao'] = 'th ah'; // "tha" broken
	arpamap['dhow'] = 'th oh'; // ?
	arpamap['toy'] = 'to oi'; // ?
	arpamap['tuh'] = 'tuh';
	arpamap['zeh'] = 'zeh';
	arpamap['maw'] = 'ma oh'; // ?
	arpamap['boy'] = 'boi';
	arpamap['by'] = 'bi'; // might mask errors with byah/byoh
	arpamap['yer'] = 'yrr'; // might mask errors with byah/byoh
	arpamap['shae'] = 'shaah'; // works for all words?
	arpamap['mr'] = 'mrr'; // split?
	arpamap['saw'] = 'sa oh'; // ?
	arpamap['chow'] = 'cho';
	arpamap['ihng'] = 'ing';
	arpamap['yuh'] = 'yu'; // ?
	arpamap['jhay'] = 'jai';
	arpamap['thay'] = 'th i'; // ?
	arpamap['dhay'] = 'th i'; // ?
	arpamap['ihz'] = 'is';
	arpamap['wao'] = 'wa';
	arpamap['zay'] = 'zai';
	arpamap['zuw'] = 'zu';
	arpamap['puw'] = 'pu';
	arpamap['shao'] = 'sha';
	arpamap['doy'] = 'doh oi'; // ?
	arpamap['jhow'] = 'jo';
	arpamap['daw'] = 'dao';
	arpamap['suw'] = 'su';
	arpamap['shuh'] = 'shu';
	arpamap['koy'] = 'koh oi'; // ?
	arpamap['vr'] = 'vrr'; // split?
	arpamap['yao'] = 'ya';
	arpamap['voy'] = 'voy';
	arpamap['vaw'] = 'va oh'; //?
	arpamap['wae'] = 'waah';
	arpamap['zuh'] = 'zu';
	arpamap['yey'] = 'yay';
	arpamap['suh'] = 'su';
	arpamap['gaw'] = 'ga oh'; // ?
	arpamap['byeh'] = 'byeh';
	arpamap['chey'] = 'chae';
	arpamap['ihn'] = 'in';
	arpamap['ruh'] = 'ru';
	arpamap['yiy'] = 'yi';
	arpamap['shuw'] = 'shu';
	arpamap['byer'] = 'byeh rr';
	arpamap['byao'] = 'byah oh';
	arpamap['shoy'] = 'sho oi'; // ?
	arpamap['jhao'] = 'ja';
	arpamap['nuh'] = 'nu';
	arpamap['wuw'] = 'wuh'; // NO "wu"
	arpamap['goy'] = 'goh oi'; // ?
	arpamap['chay'] = 'ch i'; // ?
	arpamap['show'] = 'sho';
	arpamap['byuh'] = 'byu';
	arpamap['vuw'] = 'vu';
	arpamap['byaa'] = 'byah';
	arpamap['moy'] = 'moh oi'; // ?
	arpamap['aan'] = 'on';
	arpamap['ihl'] = 'ill';
	arpamap['jhuh'] = 'ju';
	arpamap['chaa'] = 'cha';
	arpamap['choy'] = 'cho oi'; // ?
	arpamap['kyuh'] = 'kyu';
	arpamap['shaw'] = 'sha oh'; // ?
	arpamap['wr'] = 'wrr'; // ?
	arpamap['chao'] = 'cha';
	arpamap['ihf'] = 'if';
	arpamap['woy'] = 'wo oi'; // ?
	arpamap['chaw'] = 'cha oh'; // ?
	arpamap['yaw'] = 'ya oh'; // ?
	arpamap['jhaw'] = 'ja oh'; // ?
	arpamap['aet'] = 'at';
	arpamap['kyeh'] = 'kyeh';
	arpamap['yay'] = 'yai';
	arpamap['kyao'] = 'kyah';
	arpamap['chuh'] = 'chu';
	arpamap['iht'] = 'it';
	arpamap['kyih'] = 'kk ee ih'; // ???
	arpamap['aof'] = 'off';
	arpamap['aaf'] = 'off';
	arpamap['kyow'] = 'kyoh';
	arpamap['ihsh'] = 'ish';
	arpamap['soy'] = 'soh oi'; // ?
	arpamap['zoy'] = 'zoh oi'; // ?
	arpamap['waw'] = 'wa oh'; // ?
	arpamap['zaw'] = 'za oh'; // ?
	arpamap['vuh'] = 'vu';
	arpamap['ihm'] = 'im';
	
	
	// blank = combos that don't go well together (should do them separately)
	arpamap['ks'] = '';
	arpamap['zk'] = '';
	arpamap['zn'] = '';
	arpamap['vt'] = '';
	arpamap['kk'] = '';
	arpamap['dy'] = '';
	arpamap['fb'] = '';
	arpamap['lk'] = '';
	arpamap['ml'] = '';
	arpamap['zs'] = '';
	arpamap['zv'] = '';
	arpamap['df'] = '';
	arpamap['dg'] = '';
	arpamap['tz'] = '';
	arpamap['pf'] = '';
	arpamap['zf'] = '';
	arpamap['pg'] = '';
	arpamap['fd'] = '';
	arpamap['vy'] = '';
	arpamap['mf'] = '';
	arpamap['tv'] = '';
	arpamap['nr'] = ''; // ner?
	arpamap['kz'] = '';
	arpamap['sg'] = '';
	arpamap['kd'] = '';
	arpamap['lr'] = '';
	arpamap['rf'] = '';
	arpamap['mt'] = '';
	arpamap['td'] = '';
	arpamap['mv'] = '';
	arpamap['nf'] = '';
	arpamap['mw'] = '';
	arpamap['ry'] = '';
	arpamap['nw'] = '';
	arpamap['gd'] = '';
	arpamap['zl'] = '';
	arpamap['vn'] = '';
	arpamap['tk'] = '';
	arpamap['gw'] = '';
	arpamap['lg'] = '';
	arpamap['sw'] = '';
	arpamap['zw'] = '';
	arpamap['nl'] = '';
	arpamap['mg'] = '';
	arpamap['vk'] = '';
	arpamap['dk'] = '';
	arpamap['sk'] = '';
	arpamap['kw'] = '';
	arpamap['rk'] = '';
	arpamap['ds'] = '';
	arpamap['lw'] = '';
	arpamap['tf'] = '';
	arpamap['rp'] = '';
	arpamap['mp'] = '';
	arpamap['np'] = '';
	arpamap['nk'] = '';
	arpamap['rs'] = '';
	arpamap['nd'] = '';
	arpamap['tw'] = '';
	arpamap['zp'] = '';
	arpamap['dp'] = '';
	arpamap['tp'] = '';
	arpamap['ls'] = '';
	arpamap['rt'] = '';
	arpamap['rd'] = '';
	arpamap['dv'] = '';
	arpamap['rg'] = '';
	arpamap['tm'] = '';
	arpamap['bv'] = '';
	arpamap['bz'] = '';
	arpamap['bk'] = '';
	arpamap['bd'] = '';
	arpamap['dn'] = '';
	arpamap['kt'] = '';
	arpamap['lz'] = '';
	arpamap['ln'] = '';
	arpamap['kr'] = '';
	arpamap['mb'] = '';
	arpamap['rz'] = '';
	arpamap['mz'] = '';
	arpamap['dz'] = '';
	arpamap['zy'] = ''; // ??
	arpamap['lb'] = '';
	arpamap['ld'] = '';
	arpamap['bn'] = '';
	arpamap['rm'] = '';
	arpamap['rn'] = '';
	arpamap['vz'] = '';
	arpamap['vb'] = '';
	arpamap['bp'] = '';
	arpamap['lp'] = '';
	arpamap['ms'] = '';
	arpamap['pt'] = '';
	arpamap['tl'] = '';
	arpamap['tn'] = '';
	arpamap['rr'] = '';
	arpamap['bs'] = '';
	arpamap['lv'] = '';
	arpamap['vd'] = '';
	arpamap['rb'] = '';
	arpamap['dl'] = '';
	arpamap['bt'] = '';
	arpamap['bw'] = '';
	arpamap['zd'] = '';
	arpamap['zm'] = '';
	arpamap['md'] = '';
	arpamap['pn'] = '';
	arpamap['my'] = '';
	arpamap['mm'] = '';
	arpamap['vl'] = '';
	arpamap['vm'] = '';
	arpamap['km'] = '';
	arpamap['kn'] = '';
	arpamap['nz'] = '';
	arpamap['ty'] = '';
	arpamap['mk'] = '';
	arpamap['lm'] = '';
	arpamap['dw'] = '';
	arpamap['lf'] = '';
	arpamap['ns'] = '';
	arpamap['zb'] = '';
	arpamap['lt'] = '';
	arpamap['dm'] = '';
	arpamap['fs'] = '';
	arpamap['nm'] = '';
	arpamap['gn'] = '';
	arpamap['ft'] = '';
	arpamap['dt'] = '';
	arpamap['sd'] = '';
	arpamap['sm'] = '';
	arpamap['ly'] = '';
	arpamap['sp'] = '';
	arpamap['py'] = ''; // mb just pi?
	arpamap['fg'] = '';
	arpamap['fm'] = '';
	arpamap['gl'] = '';
	arpamap['gz'] = '';
	arpamap['mn'] = '';
	arpamap['gy'] = ''; // gi?
	arpamap['rw'] = '';
	arpamap['gk'] = '';
	arpamap['gf'] = '';
	arpamap['pr'] = '';
	arpamap['nt'] = '';
	arpamap['zt'] = '';
	arpamap['sb'] = '';
	arpamap['pw'] = '';
	arpamap['gs'] = '';
	arpamap['sy'] = '';
	arpamap['tg'] = '';
	arpamap['zg'] = '';
	arpamap['rl'] = '';
	arpamap['kf'] = '';
	arpamap['fk'] = '';
	arpamap['kg'] = '';
	arpamap['gb'] = '';
	arpamap['ll'] = '';
	arpamap['gt'] = '';
	arpamap['vs'] = '';
	arpamap['db'] = '';
	arpamap['gp'] = '';
	arpamap['fw'] = '';
	arpamap['kp'] = '';
	arpamap['dd'] = '';
	arpamap['rc'] = '';
	arpamap['yt'] = '';
	arpamap['bm'] = '';
	arpamap['vw'] = '';
	arpamap['kv'] = '';
	arpamap['bf'] = '';
	arpamap['ws'] = '';
	arpamap['sr'] = '';
	arpamap['rv'] = '';
	arpamap['fn'] = '';
	arpamap['nb'] = '';
	arpamap['ny'] = ''; // just do ni?
	arpamap['nv'] = '';
	arpamap['pk'] = '';
	arpamap['gm'] = '';
	arpamap['zr'] = '';
	arpamap['nn'] = '';
	arpamap['vf'] = '';
	arpamap['ss'] = '';
	arpamap['pp'] = '';
	arpamap['pd'] = '';
	arpamap['pz'] = '';
	arpamap['pb'] = '';
	arpamap['yn'] = '';
	arpamap['fp'] = '';
	arpamap['yd'] = '';
	arpamap['vp'] = '';
	arpamap['pv'] = '';
	arpamap['pm'] = '';
	arpamap['ff'] = '';
	arpamap['fz'] = '';
	arpamap['tb'] = '';
	arpamap['bg'] = '';
	arpamap['gv'] = '';
	arpamap['yw'] = '';
	arpamap['fv'] = '';
	arpamap['sv'] = '';
	arpamap['ys'] = '';
	arpamap['vg'] = '';
	arpamap['tt'] = '';
	arpamap['kb'] = '';
	arpamap['wn'] = '';
	arpamap['sn'] = '';
	arpamap['sf'] = '';
	
	
	// same as above but FIRST part is a 2-letter sound
	arpamap['awn'] = '1';
	arpamap['aal'] = '1';
	arpamap['aat'] = '1';
	arpamap['ahn'] = '1';
	arpamap['aas'] = '1';
	arpamap['awr'] = '1';
	arpamap['sht'] = '1';
	arpamap['aez'] = '1';
	arpamap['ahs'] = '1';
	arpamap['hhl'] = '1';
	arpamap['uwp'] = '1';
	arpamap['awk'] = '1';
	arpamap['hhr'] = '1';
	arpamap['hhn'] = '1';
	arpamap['aen'] = '1';
	arpamap['aed'] = '1';
	arpamap['aef'] = '1';
	arpamap['aep'] = '1';
	arpamap['aer'] = '1';
	arpamap['aev'] = '1';
	arpamap['eyd'] = '1';
	arpamap['chn'] = '1';
	arpamap['erp'] = '1';
	arpamap['eyt'] = '1';
	arpamap['aht'] = '1';
	arpamap['oyg'] = '1';
	arpamap['oys'] = '1';
	arpamap['jhd'] = '1';
	arpamap['iyn'] = '1';
	arpamap['uwn'] = '1';
	arpamap['jhm'] = '1';
	arpamap['ahv'] = '1';
	arpamap['awm'] = '1';
	arpamap['aam'] = '1';
	arpamap['shm'] = '1';
	arpamap['aes'] = '1';
	arpamap['shk'] = '1';
	arpamap['aag'] = '1';
	arpamap['aeg'] = '1';
	arpamap['own'] = '1';
	arpamap['jhr'] = '1';
	arpamap['thk'] = '1';
	arpamap['shd'] = '1';
	arpamap['shv'] = '1';
	arpamap['uwb'] = '1';
	arpamap['hhw'] = '1';
	arpamap['shf'] = '1';
	arpamap['ows'] = '1';
	arpamap['owt'] = '1';
	arpamap['jhk'] = '1';
	arpamap['ihp'] = '1';
	arpamap['shr'] = '1';
	arpamap['shw'] = '1';
	arpamap['ehr'] = '1';
	arpamap['ihd'] = '1';
	arpamap['ehz'] = '1';
	arpamap['shb'] = '1';
	arpamap['ihk'] = '1';
	arpamap['chb'] = '1';
	arpamap['chd'] = '1';
	arpamap['jhy'] = '1'; // ji?
	arpamap['aeb'] = '1';
	arpamap['erf'] = '1';
	arpamap['aak'] = '1';
	arpamap['ael'] = '1';
	arpamap['uws'] = '1';
	arpamap['jhv'] = '1';
	arpamap['ihr'] = '1';
	arpamap['chl'] = '1';
	arpamap['awz'] = '1';
	arpamap['aaz'] = '1';
	arpamap['chm'] = '1';
	arpamap['chr'] = '1';
	arpamap['chw'] = '1';
	arpamap['erz'] = '1';
	arpamap['hhm'] = '1';
	arpamap['ern'] = '1';
	arpamap['awy'] = '1';
	arpamap['erl'] = '1';
	arpamap['ehs'] = '1';
	arpamap['hhy'] = '1'; // hi?
	arpamap['erm'] = '1';
	arpamap['ers'] = '1';
	arpamap['ert'] = '1';
	arpamap['oyd'] = '1';
	arpamap['shl'] = '1';
	arpamap['erk'] = '1';
	arpamap['shy'] = '1'; // just shi?
	arpamap['chy'] = '1'; // just chi?
	arpamap['jhl'] = '1';
	arpamap['ehn'] = '1';
	arpamap['chp'] = '1';
	arpamap['thm'] = '1';
	arpamap['thd'] = '1';
	arpamap['thf'] = '1';
	arpamap['tht'] = '1';
	arpamap['thv'] = '1';
	arpamap['jhn'] = '1';
	arpamap['erd'] = '1';
	arpamap['awl'] = '1';
	arpamap['aek'] = '1';
	arpamap['ahl'] = '1';
	arpamap['ths'] = '1';
	arpamap['cht'] = '1';
	arpamap['ahz'] = '1';
	arpamap['erb'] = '1';
	arpamap['aws'] = '1';
	arpamap['chf'] = '1';
	arpamap['thr'] = '1';
	arpamap['ahp'] = '1';
	arpamap['thl'] = '1';
	arpamap['chk'] = '1';
	arpamap['uhr'] = '1';
	arpamap['zhw'] = '1';
	arpamap['owl'] = '1';
	arpamap['shn'] = '1';
	arpamap['iyz'] = '1';
	arpamap['ehl'] = '1';
	arpamap['ehv'] = '1';
	arpamap['oyt'] = '1';
	arpamap['ihs'] = '1';
	arpamap['jhp'] = '1';
	arpamap['jhs'] = '1';
	arpamap['jht'] = '1';
	arpamap['jhw'] = '1';
	arpamap['jhf'] = '1';
	arpamap['thn'] = '1';
	arpamap['ehw'] = '1';
	arpamap['aar'] = '1';
	arpamap['erv'] = '1';
	arpamap['iyk'] = '1';
	arpamap['thw'] = '1';
	arpamap['aad'] = '1';
	arpamap['ehk'] = '1';
	arpamap['ehg'] = '1';
	arpamap['shg'] = '1';
	arpamap['ngz'] = '1';
	arpamap['awb'] = '1';
	arpamap['aab'] = '1';
	arpamap['err'] = '1';
	arpamap['awt'] = '1';
	arpamap['owz'] = '1';
	arpamap['oyn'] = '1';
	arpamap['oyb'] = '1';
	arpamap['ahw'] = '1';
	arpamap['ehf'] = '1';
	arpamap['aob'] = '1';
	arpamap['erw'] = '1';
	arpamap['thy'] = '1';
	arpamap['ayn'] = '1';
	arpamap['ngk'] = '1';
	arpamap['awf'] = '1';
	arpamap['ehd'] = '1';
	arpamap['ahk'] = '1';
	arpamap['erg'] = '1';
	arpamap['ayd'] = '1';
	arpamap['aem'] = '1';
	arpamap['oyk'] = '1';
	arpamap['jhg'] = '1';
	arpamap['jhb'] = '1';
	arpamap['thb'] = '1';
	arpamap['aav'] = '1';
	arpamap['thg'] = '1';
	arpamap['ehm'] = '1';
	arpamap['ehp'] = '1';
	arpamap['ihv'] = '1';
	arpamap['ihg'] = '1';
	arpamap['uwz'] = '1';
	arpamap['shp'] = '1';
	arpamap['awd'] = '1';
	arpamap['jhz'] = '1';
	arpamap['owd'] = '1';
	arpamap['aon'] = '1';
	arpamap['eht'] = '1';
	arpamap['oyz'] = '1';
	arpamap['oyl'] = '1';
	arpamap['eyl'] = '1';
	arpamap['eraa'] = '1';
	arpamap['zhiy'] = '1'; // ?
	arpamap['erer'] = '1';
	arpamap['awer'] = '1';
	arpamap['ehhh'] = '1';
	arpamap['oyae'] = '1';
	arpamap['oysh'] = '1';
	arpamap['oydh'] = '1';
	arpamap['erah'] = '1';
	arpamap['jhhh'] = '1';
	arpamap['owzh'] = '1';
	arpamap['zhuw'] = '1';
	arpamap['thaw'] = '1';
	arpamap['zhah'] = '1';
	arpamap['aeng'] = '1';
	arpamap['awae'] = '1';
	arpamap['awih'] = '1';
	arpamap['shjh'] = '1';
	arpamap['ayah'] = '1';
	arpamap['jhsh'] = '1';
	arpamap['thae'] = '1';
	arpamap['ersh'] = '1';
	arpamap['erth'] = '1';
	arpamap['ngaa'] = '1';
	arpamap['eysh'] = '1';
	arpamap['eyjh'] = '1';
	arpamap['shhh'] = '1';
	arpamap['erjh'] = '1';
	arpamap['awdh'] = '1';
	arpamap['awth'] = '1';
	arpamap['awsh'] = '1';
	arpamap['thuw'] = '1';
	arpamap['oyeh'] = '1';
	arpamap['ihjh'] = '1';
	arpamap['eraw'] = '1';
	arpamap['erch'] = '1';
	arpamap['awch'] = '1';
	arpamap['erhh'] = '1';
	arpamap['awah'] = '1';
	arpamap['dhiy'] = '1';
	arpamap['oyih'] = '1';
	arpamap['oyer'] = '1';
	arpamap['ahdh'] = '1';
	arpamap['erey'] = '1';
	arpamap['eyiy'] = '1';
	arpamap['iyah'] = '1';
	arpamap['eruw'] = '1';
	arpamap['erao'] = '1';
	arpamap['dher'] = '1';
	arpamap['ereh'] = '1';
	arpamap['shch'] = '1';
	arpamap['zheh'] = '1';
	arpamap['aesh'] = '1';
	arpamap['dhuw'] = '1';
	arpamap['zhaa'] = '1';
	arpamap['uwih'] = '1';
	arpamap['erow'] = '1';
	arpamap['ihaa'] = '1';
	arpamap['owch'] = '1';
	arpamap['dhih'] = '1';
	arpamap['oyth'] = '1';
	arpamap['erzh'] = '1';
	arpamap['thih'] = '1';
	arpamap['thow'] = '1';
	arpamap['zhuh'] = '1';
	arpamap['byah'] = '1'; // no "byuh"??
	arpamap['thuh'] = '1';
	arpamap['erih'] = '1';
	arpamap['erae'] = '1';
	arpamap['zhih'] = '1';
	arpamap['eray'] = '1';
	arpamap['oyah'] = '1';
	arpamap['zher'] = '1';
	
	
	// same as above but SECOND part is a 2-letter sound
	arpamap['raw'] = '2';
	arpamap['yae'] = '2';
	arpamap['shh'] = '2';
	arpamap['yoy'] = '2';
	arpamap['kth'] = '2';
	arpamap['fth'] = '2';
	arpamap['zsh'] = '2';
	arpamap['gjh'] = '2';
	arpamap['vjh'] = '2';
	arpamap['rdh'] = '2';
	arpamap['vth'] = '2';
	arpamap['vch'] = '2';
	arpamap['rzh'] = '2';
	arpamap['tdh'] = '2';
	arpamap['vdh'] = '2';
	arpamap['szh'] = '2';
	arpamap['nzh'] = '2';
	arpamap['vsh'] = '2';
	arpamap['zch'] = '2';
	arpamap['gth'] = '2';
	arpamap['lzh'] = '2';
	arpamap['sdh'] = '2';
	arpamap['bth'] = '2';
	arpamap['rng'] = '2';
	arpamap['pjh'] = '2';
	arpamap['fch'] = '2';
	arpamap['tsh'] = '2';
	arpamap['ddh'] = '2';
	arpamap['tth'] = '2';
	arpamap['phh'] = '2';
	arpamap['pch'] = '2';
	arpamap['mth'] = '2';
	arpamap['dch'] = '2';
	arpamap['gzh'] = '2';
	arpamap['dth'] = '2';
	arpamap['rhh'] = '2';
	arpamap['kjh'] = '2';
	arpamap['sjh'] = '2';
	arpamap['ghh'] = '2';
	arpamap['bch'] = '2';
	arpamap['gsh'] = '2';
	arpamap['ljh'] = '2';
	arpamap['msh'] = '2';
	arpamap['rch'] = '2';
	arpamap['vhh'] = '2';
	arpamap['tjh'] = '2';
	arpamap['yih'] = '2';
	arpamap['pth'] = '2';
	arpamap['njh'] = '2';
	arpamap['tch'] = '2';
	arpamap['zjh'] = '2';
	arpamap['ker'] = '2';
	arpamap['lsh'] = '2';
	arpamap['rjh'] = '2';
	arpamap['fhh'] = '2';
	arpamap['mjh'] = '2';
	arpamap['mhh'] = '2';
	arpamap['ksh'] = '2';
	arpamap['dsh'] = '2';
	arpamap['nsh'] = '2';
	arpamap['bhh'] = '2';
	arpamap['rsh'] = '2';
	arpamap['ldh'] = '2';
	arpamap['nch'] = '2';
	arpamap['ndh'] = '2';
	arpamap['nhh'] = '2';
	arpamap['mch'] = '2';
	arpamap['lhh'] = '2';
	arpamap['bjh'] = '2';
	arpamap['bsh'] = '2';
	arpamap['psh'] = '2';
	arpamap['lth'] = '2';
	arpamap['khh'] = '2';
	arpamap['zhh'] = '2';
	arpamap['roy'] = '2';
	arpamap['kch'] = '2';
	arpamap['dhh'] = '2';	
	arpamap['djh'] = '2';	
	arpamap['rer'] = '2';	
	arpamap['thh'] = '2';	
	arpamap['sth'] = '2';	
	arpamap['nth'] = '2';	
	arpamap['rth'] = '2';	
	arpamap['fsh'] = '2';	
	arpamap['lch'] = '2';	
	arpamap['yeh'] = '2'; // no "yeh"???	
}

// converts single char to arpa phoneme
void loadLetterMap() {
	lettermap['a'] = 'aa';
	lettermap['b'] = 'b';
	lettermap['c'] = 'k';
	lettermap['d'] = 'd';
	lettermap['e'] = 'eh';
	lettermap['f'] = 'f';
	lettermap['g'] = 'g';
	lettermap['h'] = 'hh';
	lettermap['i'] = 'iy';
	lettermap['j'] = 'jh';
	lettermap['k'] = 'k';
	lettermap['l'] = 'l';
	lettermap['m'] = 'm';
	lettermap['n'] = 'n';
	lettermap['o'] = 'ow';
	lettermap['p'] = 'p';
	lettermap['q'] = 'k';
	lettermap['r'] = 'r';
	lettermap['s'] = 's';
	lettermap['t'] = 't';
	lettermap['u'] = 'uw';
	lettermap['v'] = 'v';
	lettermap['w'] = 'w';
	lettermap['x'] = 'ks';
	lettermap['y'] = 'y';
	lettermap['z'] = 'z';
}

int errs = 0;
int totalWords = 0;

// convert arpabet phoneme(s) to utaloid phoneme(s)
string convertPho(string pho, array<Phoneme>@ pronounce, bool isEndOfWord, string line="")
{
	string pre = pho.SubString(0, 2);
	bool complicated = pho.Length() >= 2 && (pre == 'hh' || pre == 'jh' || pre == 'sh' ||
											 pre == 'ky' || pre == 'by');
	
	if (pho == "N" || pho.Length() >= 3 || pho.Length() >= 2 && !complicated || isEndOfWord) 
	{
		if (arpamap.exists(pho)) 
		{
			string val;
			arpamap.get(pho, val);
			array<string> vals = val.Split(" ");
			
			if (vals.length() == 1 && (vals[0] == '' || vals[0] == '1' || vals[0] == '2'))
			{
				// 2 consonants that don't go well together. Just do one at a time
				// and hopefully the next phoneme will be a vowel
				string first, second;
				if (vals[0] == '1') // first part is a vowel
				{
					first = pho.SubString(0,2);
					second = pho.SubString(2);
				}
				else
				{
					first = pho.SubString(0,1);
					second = pho.SubString(1);
				}
				
				if (arpamap.exists(first)) {
					arpamap.get(first, val);
					pronounce.insertLast(Phoneme(val));
					pho = second;
				}
				else
				{
					println("UNKNOWN: " + pho + " WORD: " + line);
					return "!!!";
				}
				
				// end of word. Do the second consonant now since we're exiting the loop after this.
				if (isEndOfWord) {
					if (arpamap.exists(second)) {
						arpamap.get(second, val);
						pronounce.insertLast(Phoneme(val));
					} else {
						println("UNKNOWN: " + pho + " WORD: " + line);
						return "!!!";
					}
				}
			}
			else
			{
				for (uint k = 0; k < vals.length(); k++) 
				{
					pronounce.insertLast(Phoneme(vals[k]));
				}
				pho = "";
			}
		} 
		else 
		{
			println("UNKNOWN: " + pho + " WORD: " + line);
			return "!!!";
		}
	}
	return pho;
}

void loadEnglishWords(File@ f=null)
{
	// http://www.speech.cs.cmu.edu/cgi-bin/cmudict
	
	if (f is null) {
		string dataPath = "scripts/plugins/cmudict-0.7b.txt";
		@f = g_FileSystem.OpenFile( dataPath, OpenFile::READ );
	}
	
	int linesRead = 0;
	
	if( f !is null && f.IsOpen() )
	{
		string line;
		while( !f.EOFReached() )
		{
			f.ReadLine( line );
			line.Trim();
			
			if (line.Length() == 0 || line.Find(";;;") == 0 || int(line.Find("(")) != -1) {
				continue;
			}
			
			if (totalWords % 1000 == 0)
				println("Load " + ((f.Tell() / float(f.GetSize())) * 100) + "%%");
			
			string word = line.SubString(0, line.FindFirstOf(" "));
			array<string> phos = line.SubString(line.Find("  ") + 2).Split(" ");
			
			array<Phoneme> pronounce;
			
			string pho = "";
			int cons = 0;
			for (uint i = 0; i < phos.length(); i++) 
			{
				string p = phos[i];
				
				// strip "stress" number
				string last = p[p.Length()-1];
				if (last == "0" || last == "1" || last == "2")
					p = p.SubString(0, p.Length()-1);
					
				p = p.ToLowercase();
						
				if (arpamode)
				{
					pronounce.insertLast(Phoneme(p));
				}
				else
				{	
					pho += p;
					
					pho = convertPho(pho, pronounce, i == phos.length()-1, line);
					if (pho == "!!!")
						return;				
				}
				
			}
				
			
			english[word] = pronounce;
			totalWords++;
			
			if (linesRead++ > 32) {
				g_Scheduler.SetTimeout("loadEnglishWords", 0, @f);
				return;
			}
		}
	}
}

void loadVoiceData()
{	
	if (arpamode)
	{
		g_all_phonemes.insertLast(Phoneme("aa"));
		g_all_phonemes.insertLast(Phoneme("ae"));
		g_all_phonemes.insertLast(Phoneme("ah"));
		g_all_phonemes.insertLast(Phoneme("ao"));
		g_all_phonemes.insertLast(Phoneme("aw"));
		g_all_phonemes.insertLast(Phoneme("ay"));
		g_all_phonemes.insertLast(Phoneme("b"));
		g_all_phonemes.insertLast(Phoneme("ch"));
		g_all_phonemes.insertLast(Phoneme("d"));
		g_all_phonemes.insertLast(Phoneme("dh"));
		g_all_phonemes.insertLast(Phoneme("eh"));
		g_all_phonemes.insertLast(Phoneme("er"));
		g_all_phonemes.insertLast(Phoneme("ey"));
		g_all_phonemes.insertLast(Phoneme("f"));
		g_all_phonemes.insertLast(Phoneme("g"));
		g_all_phonemes.insertLast(Phoneme("hh"));
		g_all_phonemes.insertLast(Phoneme("ih"));
		g_all_phonemes.insertLast(Phoneme("iy"));
		g_all_phonemes.insertLast(Phoneme("jh"));
		g_all_phonemes.insertLast(Phoneme("k"));
		g_all_phonemes.insertLast(Phoneme("l"));
		g_all_phonemes.insertLast(Phoneme("m"));
		g_all_phonemes.insertLast(Phoneme("n"));
		g_all_phonemes.insertLast(Phoneme("ng"));
		g_all_phonemes.insertLast(Phoneme("ow"));
		g_all_phonemes.insertLast(Phoneme("oy"));
		g_all_phonemes.insertLast(Phoneme("o"));
		g_all_phonemes.insertLast(Phoneme("p"));
		g_all_phonemes.insertLast(Phoneme("r"));
		g_all_phonemes.insertLast(Phoneme("s"));
		g_all_phonemes.insertLast(Phoneme("sh"));
		g_all_phonemes.insertLast(Phoneme("t"));
		g_all_phonemes.insertLast(Phoneme("th"));
		g_all_phonemes.insertLast(Phoneme("uh"));
		g_all_phonemes.insertLast(Phoneme("uw"));
		g_all_phonemes.insertLast(Phoneme("v"));
		g_all_phonemes.insertLast(Phoneme("w"));
		g_all_phonemes.insertLast(Phoneme("y"));
		g_all_phonemes.insertLast(Phoneme("z"));
		g_all_phonemes.insertLast(Phoneme("zh"));
	}
	else
	{
		g_all_phonemes.insertLast(Phoneme("aah"));
		g_all_phonemes.insertLast(Phoneme("ae"));
		g_all_phonemes.insertLast(Phoneme("aft"));
		g_all_phonemes.insertLast(Phoneme("ah"));
		g_all_phonemes.insertLast(Phoneme("air"));
		g_all_phonemes.insertLast(Phoneme("all"));
		g_all_phonemes.insertLast(Phoneme("an"));
		g_all_phonemes.insertLast(Phoneme("ao"));
		g_all_phonemes.insertLast(Phoneme("as"));
		g_all_phonemes.insertLast(Phoneme("at"));
		g_all_phonemes.insertLast(Phoneme("ba"));
		g_all_phonemes.insertLast(Phoneme("baah"));
		g_all_phonemes.insertLast(Phoneme("bae"));
		g_all_phonemes.insertLast(Phoneme("bai"));
		g_all_phonemes.insertLast(Phoneme("beh"));
		g_all_phonemes.insertLast(Phoneme("bi"));
		g_all_phonemes.insertLast(Phoneme("bih"));
		g_all_phonemes.insertLast(Phoneme("bl"));
		g_all_phonemes.insertLast(Phoneme("boh"));
		g_all_phonemes.insertLast(Phoneme("boi"));
		g_all_phonemes.insertLast(Phoneme("brr"));
		g_all_phonemes.insertLast(Phoneme("bu"));
		g_all_phonemes.insertLast(Phoneme("buh"));
		g_all_phonemes.insertLast(Phoneme("byah"));
		g_all_phonemes.insertLast(Phoneme("byeh"));
		g_all_phonemes.insertLast(Phoneme("byoh"));
		g_all_phonemes.insertLast(Phoneme("byu"));
		g_all_phonemes.insertLast(Phoneme("cah"));
		g_all_phonemes.insertLast(Phoneme("cal"));
		g_all_phonemes.insertLast(Phoneme("ch"));
		g_all_phonemes.insertLast(Phoneme("cha"));
		g_all_phonemes.insertLast(Phoneme("chae"));
		g_all_phonemes.insertLast(Phoneme("chan"));
		g_all_phonemes.insertLast(Phoneme("cheh"));
		g_all_phonemes.insertLast(Phoneme("chi"));
		g_all_phonemes.insertLast(Phoneme("cho"));
		g_all_phonemes.insertLast(Phoneme("chu"));
		g_all_phonemes.insertLast(Phoneme("co"));
		g_all_phonemes.insertLast(Phoneme("cri"));
		g_all_phonemes.insertLast(Phoneme("crr"));
		g_all_phonemes.insertLast(Phoneme("cuh"));
		g_all_phonemes.insertLast(Phoneme("cyah"));
		g_all_phonemes.insertLast(Phoneme("da"));
		g_all_phonemes.insertLast(Phoneme("daah"));
		g_all_phonemes.insertLast(Phoneme("dae"));
		g_all_phonemes.insertLast(Phoneme("dai"));
		g_all_phonemes.insertLast(Phoneme("dao"));
		g_all_phonemes.insertLast(Phoneme("dar"));
		g_all_phonemes.insertLast(Phoneme("deh"));
		g_all_phonemes.insertLast(Phoneme("di"));
		g_all_phonemes.insertLast(Phoneme("dih"));
		g_all_phonemes.insertLast(Phoneme("doh"));
		g_all_phonemes.insertLast(Phoneme("drr"));
		g_all_phonemes.insertLast(Phoneme("du"));
		g_all_phonemes.insertLast(Phoneme("duh"));
		g_all_phonemes.insertLast(Phoneme("ee"));
		g_all_phonemes.insertLast(Phoneme("eh"));
		g_all_phonemes.insertLast(Phoneme("er"));
		g_all_phonemes.insertLast(Phoneme("est"));
		g_all_phonemes.insertLast(Phoneme("fa"));
		g_all_phonemes.insertLast(Phoneme("fae"));
		g_all_phonemes.insertLast(Phoneme("fah"));
		g_all_phonemes.insertLast(Phoneme("fai"));
		g_all_phonemes.insertLast(Phoneme("feh"));
		g_all_phonemes.insertLast(Phoneme("fi"));
		g_all_phonemes.insertLast(Phoneme("fih"));
		g_all_phonemes.insertLast(Phoneme("fll"));
		g_all_phonemes.insertLast(Phoneme("foh"));
		g_all_phonemes.insertLast(Phoneme("for"));
		g_all_phonemes.insertLast(Phoneme("frr"));
		g_all_phonemes.insertLast(Phoneme("fu"));
		g_all_phonemes.insertLast(Phoneme("fuh"));
		g_all_phonemes.insertLast(Phoneme("full"));
		g_all_phonemes.insertLast(Phoneme("fyah"));
		g_all_phonemes.insertLast(Phoneme("fyoh"));
		g_all_phonemes.insertLast(Phoneme("fyu"));
		g_all_phonemes.insertLast(Phoneme("ga"));
		g_all_phonemes.insertLast(Phoneme("gae"));
		g_all_phonemes.insertLast(Phoneme("gai"));
		g_all_phonemes.insertLast(Phoneme("gar"));
		g_all_phonemes.insertLast(Phoneme("geh"));
		g_all_phonemes.insertLast(Phoneme("gi"));
		g_all_phonemes.insertLast(Phoneme("gih"));
		g_all_phonemes.insertLast(Phoneme("gll"));
		g_all_phonemes.insertLast(Phoneme("goh"));
		g_all_phonemes.insertLast(Phoneme("grr"));
		g_all_phonemes.insertLast(Phoneme("grr1"));
		g_all_phonemes.insertLast(Phoneme("gu"));
		g_all_phonemes.insertLast(Phoneme("guh"));
		g_all_phonemes.insertLast(Phoneme("gyah"));
		g_all_phonemes.insertLast(Phoneme("gyeh"));
		g_all_phonemes.insertLast(Phoneme("gyi"));
		g_all_phonemes.insertLast(Phoneme("gyoh"));
		g_all_phonemes.insertLast(Phoneme("gyu"));
		g_all_phonemes.insertLast(Phoneme("ha"));
		g_all_phonemes.insertLast(Phoneme("haah"));
		g_all_phonemes.insertLast(Phoneme("hae"));
		g_all_phonemes.insertLast(Phoneme("hai"));
		g_all_phonemes.insertLast(Phoneme("har"));
		g_all_phonemes.insertLast(Phoneme("heh"));
		g_all_phonemes.insertLast(Phoneme("ho"));
		g_all_phonemes.insertLast(Phoneme("hu"));
		g_all_phonemes.insertLast(Phoneme("huh"));
		g_all_phonemes.insertLast(Phoneme("hyah"));
		g_all_phonemes.insertLast(Phoneme("hyoh"));
		g_all_phonemes.insertLast(Phoneme("hyu"));
		g_all_phonemes.insertLast(Phoneme("i"));
		g_all_phonemes.insertLast(Phoneme("if"));
		g_all_phonemes.insertLast(Phoneme("ih"));
		g_all_phonemes.insertLast(Phoneme("ill"));
		g_all_phonemes.insertLast(Phoneme("im"));
		g_all_phonemes.insertLast(Phoneme("in"));
		g_all_phonemes.insertLast(Phoneme("ing"));
		g_all_phonemes.insertLast(Phoneme("is"));
		g_all_phonemes.insertLast(Phoneme("ish"));
		g_all_phonemes.insertLast(Phoneme("it"));
		g_all_phonemes.insertLast(Phoneme("ja"));
		g_all_phonemes.insertLast(Phoneme("jae"));
		g_all_phonemes.insertLast(Phoneme("jai"));
		g_all_phonemes.insertLast(Phoneme("jeh"));
		g_all_phonemes.insertLast(Phoneme("ji"));
		g_all_phonemes.insertLast(Phoneme("jo"));
		g_all_phonemes.insertLast(Phoneme("ju"));
		g_all_phonemes.insertLast(Phoneme("jyah"));
		g_all_phonemes.insertLast(Phoneme("jyeh"));
		g_all_phonemes.insertLast(Phoneme("jyi"));
		g_all_phonemes.insertLast(Phoneme("jyoh"));
		g_all_phonemes.insertLast(Phoneme("jyu"));
		g_all_phonemes.insertLast(Phoneme("ka"));
		g_all_phonemes.insertLast(Phoneme("kae"));
		g_all_phonemes.insertLast(Phoneme("kai"));
		g_all_phonemes.insertLast(Phoneme("keh"));
		g_all_phonemes.insertLast(Phoneme("ki"));
		g_all_phonemes.insertLast(Phoneme("kih"));
		g_all_phonemes.insertLast(Phoneme("kk"));
		g_all_phonemes.insertLast(Phoneme("kll"));
		g_all_phonemes.insertLast(Phoneme("koh"));
		g_all_phonemes.insertLast(Phoneme("ku"));
		g_all_phonemes.insertLast(Phoneme("kuh"));
		g_all_phonemes.insertLast(Phoneme("kyah"));
		g_all_phonemes.insertLast(Phoneme("kyeh"));
		g_all_phonemes.insertLast(Phoneme("kyoh"));
		g_all_phonemes.insertLast(Phoneme("kyu"));
		g_all_phonemes.insertLast(Phoneme("la"));
		g_all_phonemes.insertLast(Phoneme("laah"));
		g_all_phonemes.insertLast(Phoneme("lae"));
		g_all_phonemes.insertLast(Phoneme("lai"));
		g_all_phonemes.insertLast(Phoneme("lao"));
		g_all_phonemes.insertLast(Phoneme("lect"));
		g_all_phonemes.insertLast(Phoneme("leh"));
		g_all_phonemes.insertLast(Phoneme("li"));
		g_all_phonemes.insertLast(Phoneme("lih"));
		g_all_phonemes.insertLast(Phoneme("ll"));
		g_all_phonemes.insertLast(Phoneme("loh"));
		g_all_phonemes.insertLast(Phoneme("lrr"));
		g_all_phonemes.insertLast(Phoneme("lu"));
		g_all_phonemes.insertLast(Phoneme("luh"));
		g_all_phonemes.insertLast(Phoneme("ma"));
		g_all_phonemes.insertLast(Phoneme("maah"));
		g_all_phonemes.insertLast(Phoneme("mae"));
		g_all_phonemes.insertLast(Phoneme("mai"));
		g_all_phonemes.insertLast(Phoneme("meh"));
		g_all_phonemes.insertLast(Phoneme("mi"));
		g_all_phonemes.insertLast(Phoneme("mih"));
		g_all_phonemes.insertLast(Phoneme("mir"));
		g_all_phonemes.insertLast(Phoneme("mm"));
		g_all_phonemes.insertLast(Phoneme("moh"));
		g_all_phonemes.insertLast(Phoneme("mrr"));
		g_all_phonemes.insertLast(Phoneme("mu"));
		g_all_phonemes.insertLast(Phoneme("muh"));
		g_all_phonemes.insertLast(Phoneme("myah"));
		g_all_phonemes.insertLast(Phoneme("myoh"));
		g_all_phonemes.insertLast(Phoneme("myu"));
		g_all_phonemes.insertLast(Phoneme("na"));
		g_all_phonemes.insertLast(Phoneme("naah"));
		g_all_phonemes.insertLast(Phoneme("nae"));
		g_all_phonemes.insertLast(Phoneme("nai"));
		g_all_phonemes.insertLast(Phoneme("nao"));
		g_all_phonemes.insertLast(Phoneme("neh"));
		g_all_phonemes.insertLast(Phoneme("nell"));
		g_all_phonemes.insertLast(Phoneme("ner"));
		g_all_phonemes.insertLast(Phoneme("ni"));
		g_all_phonemes.insertLast(Phoneme("nih"));
		g_all_phonemes.insertLast(Phoneme("nn"));
		g_all_phonemes.insertLast(Phoneme("no"));
		g_all_phonemes.insertLast(Phoneme("nrr"));
		g_all_phonemes.insertLast(Phoneme("ns"));
		g_all_phonemes.insertLast(Phoneme("nu"));
		g_all_phonemes.insertLast(Phoneme("nuh"));
		g_all_phonemes.insertLast(Phoneme("nyah"));
		g_all_phonemes.insertLast(Phoneme("nyeh"));
		g_all_phonemes.insertLast(Phoneme("nyo"));
		g_all_phonemes.insertLast(Phoneme("nyu"));
		g_all_phonemes.insertLast(Phoneme("odd"));
		g_all_phonemes.insertLast(Phoneme("of"));
		g_all_phonemes.insertLast(Phoneme("off"));
		g_all_phonemes.insertLast(Phoneme("oh"));
		g_all_phonemes.insertLast(Phoneme("oi"));
		g_all_phonemes.insertLast(Phoneme("on"));
		g_all_phonemes.insertLast(Phoneme("ong"));
		g_all_phonemes.insertLast(Phoneme("op"));
		g_all_phonemes.insertLast(Phoneme("or"));
		g_all_phonemes.insertLast(Phoneme("ous"));
		g_all_phonemes.insertLast(Phoneme("pa"));
		g_all_phonemes.insertLast(Phoneme("paah"));
		g_all_phonemes.insertLast(Phoneme("pae"));
		g_all_phonemes.insertLast(Phoneme("pai"));
		g_all_phonemes.insertLast(Phoneme("pao"));
		g_all_phonemes.insertLast(Phoneme("peh"));
		g_all_phonemes.insertLast(Phoneme("per"));
		g_all_phonemes.insertLast(Phoneme("pi"));
		g_all_phonemes.insertLast(Phoneme("pih"));
		g_all_phonemes.insertLast(Phoneme("pll"));
		g_all_phonemes.insertLast(Phoneme("poi"));
		g_all_phonemes.insertLast(Phoneme("pra"));
		g_all_phonemes.insertLast(Phoneme("pro"));
		g_all_phonemes.insertLast(Phoneme("ps"));
		g_all_phonemes.insertLast(Phoneme("pu"));
		g_all_phonemes.insertLast(Phoneme("puh"));
		g_all_phonemes.insertLast(Phoneme("pull"));
		g_all_phonemes.insertLast(Phoneme("pyah"));
		g_all_phonemes.insertLast(Phoneme("pyeh"));
		g_all_phonemes.insertLast(Phoneme("pyoh"));
		g_all_phonemes.insertLast(Phoneme("pyuu"));
		g_all_phonemes.insertLast(Phoneme("queh"));
		g_all_phonemes.insertLast(Phoneme("qui"));
		g_all_phonemes.insertLast(Phoneme("raah"));
		g_all_phonemes.insertLast(Phoneme("rae"));
		g_all_phonemes.insertLast(Phoneme("rah"));
		g_all_phonemes.insertLast(Phoneme("rai"));
		g_all_phonemes.insertLast(Phoneme("reh"));
		g_all_phonemes.insertLast(Phoneme("rell"));
		g_all_phonemes.insertLast(Phoneme("ri"));
		g_all_phonemes.insertLast(Phoneme("rih"));
		g_all_phonemes.insertLast(Phoneme("roh"));
		g_all_phonemes.insertLast(Phoneme("rr"));
		g_all_phonemes.insertLast(Phoneme("ru"));
		g_all_phonemes.insertLast(Phoneme("ruh"));
		g_all_phonemes.insertLast(Phoneme("rus"));
		g_all_phonemes.insertLast(Phoneme("ryah"));
		g_all_phonemes.insertLast(Phoneme("ryoh"));
		g_all_phonemes.insertLast(Phoneme("ryu"));
		g_all_phonemes.insertLast(Phoneme("sa"));
		g_all_phonemes.insertLast(Phoneme("saah"));
		g_all_phonemes.insertLast(Phoneme("sae"));
		g_all_phonemes.insertLast(Phoneme("sah"));
		g_all_phonemes.insertLast(Phoneme("sai"));
		g_all_phonemes.insertLast(Phoneme("seh"));
		g_all_phonemes.insertLast(Phoneme("sha"));
		g_all_phonemes.insertLast(Phoneme("shaah"));
		g_all_phonemes.insertLast(Phoneme("shar"));
		g_all_phonemes.insertLast(Phoneme("shi"));
		g_all_phonemes.insertLast(Phoneme("sho"));
		g_all_phonemes.insertLast(Phoneme("shu"));
		g_all_phonemes.insertLast(Phoneme("si"));
		g_all_phonemes.insertLast(Phoneme("sih"));
		g_all_phonemes.insertLast(Phoneme("sll"));
		g_all_phonemes.insertLast(Phoneme("soh"));
		g_all_phonemes.insertLast(Phoneme("srr"));
		g_all_phonemes.insertLast(Phoneme("ss"));
		g_all_phonemes.insertLast(Phoneme("ssh"));
		g_all_phonemes.insertLast(Phoneme("st"));
		g_all_phonemes.insertLast(Phoneme("su"));
		g_all_phonemes.insertLast(Phoneme("suh"));
		g_all_phonemes.insertLast(Phoneme("syah"));
		g_all_phonemes.insertLast(Phoneme("ta"));
		g_all_phonemes.insertLast(Phoneme("taah"));
		g_all_phonemes.insertLast(Phoneme("tae"));
		g_all_phonemes.insertLast(Phoneme("tai"));
		g_all_phonemes.insertLast(Phoneme("tar"));
		g_all_phonemes.insertLast(Phoneme("tear"));
		g_all_phonemes.insertLast(Phoneme("teh"));
		g_all_phonemes.insertLast(Phoneme("th"));
		g_all_phonemes.insertLast(Phoneme("tha"));
		g_all_phonemes.insertLast(Phoneme("thank"));
		g_all_phonemes.insertLast(Phoneme("the"));
		g_all_phonemes.insertLast(Phoneme("they"));
		g_all_phonemes.insertLast(Phoneme("thuh"));
		g_all_phonemes.insertLast(Phoneme("ti"));
		g_all_phonemes.insertLast(Phoneme("tic"));
		g_all_phonemes.insertLast(Phoneme("tih"));
		g_all_phonemes.insertLast(Phoneme("tion"));
		g_all_phonemes.insertLast(Phoneme("to"));
		g_all_phonemes.insertLast(Phoneme("trr"));
		g_all_phonemes.insertLast(Phoneme("ts"));
		g_all_phonemes.insertLast(Phoneme("tsu"));
		g_all_phonemes.insertLast(Phoneme("tt"));
		g_all_phonemes.insertLast(Phoneme("tu"));
		g_all_phonemes.insertLast(Phoneme("tuh"));
		g_all_phonemes.insertLast(Phoneme("u"));
		g_all_phonemes.insertLast(Phoneme("uh"));
		g_all_phonemes.insertLast(Phoneme("um"));
		g_all_phonemes.insertLast(Phoneme("un"));
		g_all_phonemes.insertLast(Phoneme("va"));
		g_all_phonemes.insertLast(Phoneme("vae"));
		g_all_phonemes.insertLast(Phoneme("vah"));
		g_all_phonemes.insertLast(Phoneme("vai"));
		g_all_phonemes.insertLast(Phoneme("veh"));
		g_all_phonemes.insertLast(Phoneme("vell"));
		g_all_phonemes.insertLast(Phoneme("voh"));
		g_all_phonemes.insertLast(Phoneme("voy"));
		g_all_phonemes.insertLast(Phoneme("vrr"));
		g_all_phonemes.insertLast(Phoneme("vu"));
		g_all_phonemes.insertLast(Phoneme("vuh"));
		g_all_phonemes.insertLast(Phoneme("vv"));
		g_all_phonemes.insertLast(Phoneme("wa"));
		g_all_phonemes.insertLast(Phoneme("waah"));
		g_all_phonemes.insertLast(Phoneme("wae"));
		g_all_phonemes.insertLast(Phoneme("weh"));
		g_all_phonemes.insertLast(Phoneme("wi"));
		g_all_phonemes.insertLast(Phoneme("with"));
		g_all_phonemes.insertLast(Phoneme("wo"));
		g_all_phonemes.insertLast(Phoneme("wrr"));
		g_all_phonemes.insertLast(Phoneme("wuh"));
		g_all_phonemes.insertLast(Phoneme("xx"));
		g_all_phonemes.insertLast(Phoneme("ya"));
		g_all_phonemes.insertLast(Phoneme("yai"));
		g_all_phonemes.insertLast(Phoneme("yar"));
		g_all_phonemes.insertLast(Phoneme("yay"));
		g_all_phonemes.insertLast(Phoneme("yes"));
		g_all_phonemes.insertLast(Phoneme("yi"));
		g_all_phonemes.insertLast(Phoneme("yoh"));
		g_all_phonemes.insertLast(Phoneme("yrr"));
		g_all_phonemes.insertLast(Phoneme("yu"));
		g_all_phonemes.insertLast(Phoneme("yuh"));
		g_all_phonemes.insertLast(Phoneme("za"));
		g_all_phonemes.insertLast(Phoneme("zah"));
		g_all_phonemes.insertLast(Phoneme("zai"));
		g_all_phonemes.insertLast(Phoneme("zeh"));
		g_all_phonemes.insertLast(Phoneme("zoh"));
		g_all_phonemes.insertLast(Phoneme("zu"));
		g_all_phonemes.insertLast(Phoneme("zuh"));
		g_all_phonemes.insertLast(Phoneme("zz"));
	}
}

void playSoundDelay(CBasePlayer@ plr, Phoneme@ pho) {
	float vol = 1.0f;
	g_SoundSystem.PlaySound(plr.edict(), CHAN_VOICE, pho.soundFile, vol, 1.0f, 0, pho.pitch, 0, true, plr.pev.origin);
}

float arpaLen(string c)
{
	if (c == "l") return 0.15f;
	if (c == "r") return 0.2f;
	if (c == "b") return 0.05f;
	if (c == "g") return 0.06f;
	if (c == "dh") return 0.075f;
	if (c == "jh" || c == "r") return 0.15f;
	if (c.Length() == 1 || c == "hh" || c == "th") return 0.1f;
	return 0.15f;
}

// break a word down into phonemes
array<Phoneme> getPhonemes(string word)
{
	array<Phoneme> phos;
	
	word = word.ToUppercase();
	if (english.exists(word)) {
		phos = cast<array<Phoneme>>(english[word]);
	} else { // freestyle it
		string pho = "";
		for (uint i = 0; i < word.Length(); i++)
		{
			string letter = word[i];
			letter = letter.ToLowercase();
			if (lettermap.exists(letter)) {
				string val;
				lettermap.get(letter, val);
				pho += val;
				if (arpamode)
				{
					Phoneme@ p = Phoneme(val);					
					phos.insertLast(p);
					continue;
				}
			} else {
				println("NO LETTER FOR: " + letter);
				continue;
			}

			
			pho = convertPho(pho, phos, i == word.Length()-1, word);
		}
	}
	
	//phos.insertLast(Phoneme("bi", 100, 0.2f));
	//phos.insertLast(Phoneme("ing", 95, 0.1f));
	//phos.insertLast(Phoneme(".", 100, 0.4f));
	//phos.insertLast(Phoneme("wuh", 100, 0.2f));
	//phos.insertLast(Phoneme("nn", 95, 0.2f));

	return phos;
}

// handles player chats
void doSpeech(CBasePlayer@ plr, const CCommand@ args)
{	
	float vol = 1.0f;
	float delay = 0;
	for (int i = 0; i < args.ArgC(); i++)
	{
		string word = args[i];
		
		array<Phoneme> phos = getPhonemes(word);
		
		for (uint k = 0; k < phos.length(); k++) {
			Phoneme@ pho = phos[k];
			println("SPEAK: " + pho.code);
			
			if (pho.code == ".") {
				delay += 0.4f;
			} else {
				g_Scheduler.SetTimeout("playSoundDelay", delay, @plr, @pho);
				delay += pho.len;
			}
		}
		
		delay += 0.2;
	}
}


// Will create a new state if the requested one does not exit
PlayerState@ getPlayerState(CBasePlayer@ plr)
{	
	string steamId = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	if (steamId == 'STEAM_ID_LAN') {
		steamId = plr.pev.netname;
	}
	
	if ( !player_states.exists(steamId) )
	{
		PlayerState state;
		state.talker_id = default_voice;
		state.pitch = 100;
		player_states[steamId] = state;
	}
	return cast<PlayerState@>( player_states[steamId] );
}

bool doCommand(CBasePlayer@ plr, const CCommand@ args)
{
	PlayerState@ state = getPlayerState(plr);
	
	if ( args.ArgC() > 0 )
	{
		if ( args[0] == ".vc" )
		{

		}
	}
	return false;
}

HookReturnCode ClientSay( SayParameters@ pParams )
{	
	CBasePlayer@ plr = pParams.GetPlayer();
	const CCommand@ args = pParams.GetArguments();
	
	if (doCommand(plr, args))
	{
		pParams.ShouldHide = true;
		return HOOK_HANDLED;
	}
	else {		
		doSpeech(plr, args);
	}
	
	return HOOK_CONTINUE;
}

CClientCommand _noclip("vc", "Voice command menu", @voiceCmd );

void voiceCmd( const CCommand@ args )
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	doCommand(plr, args);
}