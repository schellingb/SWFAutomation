//--------------------------------------------//
// SWFAutomation                              //
// License: Public Domain (www.unlicense.org) //
//--------------------------------------------//

static const char* MozRepl_Host = "127.0.0.1";
static const int   MozRepl_Port = 4242;

#ifdef _WIN32
#define _CRT_SECURE_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#define _HAS_EXCEPTIONS 0
#if defined(_MSC_VER)
#pragma warning(push)
#pragma warning(disable:4702) //unreachable code
#include <xtree>
#pragma warning(pop)
#endif
#endif

#define STS_NET_IMPLEMENTATION
#define STS_NET_NO_PACKETS
#define STS_NET_NO_ERRORSTRINGS
#include "sts_net.inl"

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <string>

static std::string Format(const char *format, ...);

static void MozRepl_ConsoleLog(const char *str);
static std::string MozRepl_SendCmd(const char* cmd);
static bool MozRepl_Connect(const char* Host, int Port);
static void MozRepl_Disconnect();

static bool SWFAutomation_Startup(const char* url, const char* SetElementJS = "document.getElementsByTagName('embed')[0]||document.getElementsByTagName('object')[0]");
static void SWFAutomation_Shutdown();
static std::string SWFAutomation_Run(const char* cmd);
static bool SWFAutomation_RunUntilEqual(const char* cmd, const char* result, int WaitTime = 800, int WaitRepeat = 50);
static std::string SWFAutomation_RunUntilNotEmpty(const char* cmd, int WaitTime = 800, int WaitRepeat = 50);

static void RunTest(const char* Info, const char* Cmd)
{
	MozRepl_ConsoleLog(Format("%s: %s", Info, SWFAutomation_Run(Cmd).c_str()).c_str());
}

int main(int, char *[])
{
	if (!MozRepl_Connect(MozRepl_Host, MozRepl_Port)) return 1;

	MozRepl_ConsoleLog(" 1. STARTING SWF AUTOMATION ...");
	if (!SWFAutomation_Startup("http://www.adobe.com/devnet/actionscript/samples/interactivity_1.html", "document.getElementsByTagName('object')[0]")) return 1;

	MozRepl_ConsoleLog(" 2. WAITING UNTIL PAGE IS LOADED AND SWF IS INITIALIZED ...");
	if (!SWFAutomation_RunUntilEqual("inj_active()", "true", 5000)) return 1;

	RunTest(" 3. GETTING ATTRIBUTE beetle/shadow.scaleY",                                       "inj_get('beetle/shadow', 'scaleY')");
	RunTest(" 4. SETTING ATTRIBUTE beetle/shadow.scaleX TO 1.5",                                "inj_set('beetle/shadow', 'scaleX', 1.5)");
	RunTest(" 5. MOVING OBJECT beetle TO 300,80",                                               "inj_move('beetle', 300, 80)");
	RunTest(" 6. CALLING FUNCTION beetle.toString(); ",                                         "inj_call('beetle', 'toString')");
	RunTest(" 7. SENDING CLICK EVENT TO toggle_btn",                                            "inj_click('toggle_btn')");
	RunTest(" 8. GETTING STATIC ATTRIBUTE flash.system.System.totalMemory",                     "inj_static_get('flash.system.System', 'totalMemory')");
	RunTest(" 9. SETTING STATIC ATTRIBUTE flash.ui.Mouse.cursor TO 'hand'",                     "inj_static_set('flash.ui.Mouse', 'cursor', 'hand')");
	RunTest("10. CALLING STATIC FUNCTION flash.external.ExternalInterface.call('eval', '4+3')", "inj_static_call('flash.external.ExternalInterface', 'call', 'eval', '4+3')");

	MozRepl_ConsoleLog("11. CLEANING UP SWF AUTOMATION ...");
	SWFAutomation_Shutdown();

	MozRepl_ConsoleLog("12. DONE! Closing connection.");
	MozRepl_Disconnect();

	return 0;
}

//--------------------------------------------------------------------------------------------------------------------------------------

#define LogText(...) fprintf(stdout, __VA_ARGS__),fprintf(stdout, "\n")
#define LogError(...) fprintf(stderr, __VA_ARGS__),fprintf(stderr, "\n\n")

static void SleepMS(unsigned int ms)
{
	#ifdef _WIN32
	Sleep(ms);
	#else
	timespec req, rem;
	req.tv_sec = ms / 1000;
	req.tv_nsec = (ms % 1000) * 1000000ULL;
	while (nanosleep(&req, &rem)) req = rem;
	#endif
}

static std::string Format(const char *format, ...)
{
	std::string str;
	str.resize(strlen(format) + 16, ' ');
	for (int n;;str.resize(n > 0 ? n+1 : str.size()*2, ' '))
	{
		va_list ap; va_start(ap, format); n = vsnprintf(&str[0], str.size(), format, ap); va_end(ap); 
		if (n >= 0 && n <= (int)str.size()) { str.resize(n); break; }
	}
	return str;
}

static void Replace(std::string& str, const char* from, const char* to)
{
	for (std::string::size_type fromlen = strlen(from), tolen = strlen(to), f = str.find(from); f != std::string::npos; f = str.find(from, f + tolen))
		str.replace(f, fromlen, to);
}

//--------------------------------------------------------------------------------------------------------------------------------------

static bool SWFAutomation_Startup(const char* url, const char* SetElementJS)
{
	//this loops through all open windows/tabs to find an open tab to the requested url and if not found opens a new tab to it - then it returns the window handle to the window showing that tab
	std::string MozHWND = MozRepl_SendCmd(Format(
		"MOZREPL.print((function()"
		"{"
			"MOZREPL.se = \"if (!this.swae) try{ swae = %s; }catch(e){}\";"
			"var tab, w, url = '%s', e = Components.classes['@mozilla.org/appshell/window-mediator;1'].getService(Ci.nsIWindowMediator).getEnumerator(null);"
			"while (!tab && e && (w = e.getNext()))"
			"{"
				"for (var nodes = w.getBrowser().tabContainer.childNodes, i = 0; !tab && i < nodes.length; i++)"
				"{"
					"var cw = nodes[i].linkedBrowser.contentWindow, loc = cw.location, href = loc.href, doc = cw.document;"
					"if (href != url) continue;"
					"tab = nodes[i];"
					"var ret = cw.eval(MOZREPL.se + 'this.swae?swae.inj_get?2:1:0');"
					"if (ret == 0) { if (doc.body) doc.body.innerHTML = ''; loc.href = url; }"
					"if (ret == 1) cw.eval('swae = swae.parentElement;this.swaehtml = swae.innerHTML;swae.innerHTML = swaehtml;delete swaehtml;delete swae');"
				"}"
			"}"
			"if (!tab) w = (getBrowser().addTab ? this : Components.classes['@mozilla.org/appshell/window-mediator;1'].getService(Ci.nsIWindowMediator).getEnumerator(null).getNext());"
			"if (!tab) tab = w.getBrowser().addTab(url);"
			"MOZREPL.w = tab.linkedBrowser.contentWindow;"
			"w.getBrowser().selectedTab = tab;"
			"return w.getInterface(Ci.nsIWebNavigation).QueryInterface(Ci.nsIDocShellTreeItem).treeOwner.nsIBaseWindow.nativeHandle;"
		"})());", SetElementJS, url).c_str());

	if (MozHWND.length() < 3 || MozHWND[0] != '0' || MozHWND[1] != 'x') //should start with 0x
	{
		LogError("[SWFAutomation_Startup] Could not set up SWF Automation - Error: %s", MozHWND.c_str());
		return false;
	}
	return true;
}

static void SWFAutomation_Shutdown()
{
	MozRepl_SendCmd("(function(){delete MOZREPL.w;delete MOZREPL.se;return;})();1;");
}

static std::string SWFAutomation_Run(const char* cmd)
{
	std::string sendcmd = cmd;
	Replace(sendcmd, "'", "\\'");
	std::string res = MozRepl_SendCmd(Format("MOZREPL.print(MOZREPL.w.eval(MOZREPL.se + '(this.swae&&swae.inj_get?swae.%s:\\'SWFAUTO_ERROR\\')'))", sendcmd.c_str()).c_str());
	//MozRepl_ConsoleLog(Format("[SWFAUTOMATION_RUN] swae.%s ==> [%s]", cmd, res.c_str()).c_str()); //debug
	return res;
}

//static double SWFAutomation_RunNumber(const char* cmd)
//{
//	std::string res = SWFAutomation_Run(cmd);
//	double num = 0;
//	sscanf(res.c_str(), "%lf", &num);
//	return num;
//}

static bool SWFAutomation_RunUntilEqual(const char* cmd, const char* result, int WaitTime, int WaitRepeat)
{
	for (int i = 0, iEnd = ((WaitTime+WaitRepeat-1) / WaitRepeat); i != iEnd; i++)
	{
		if (SWFAutomation_Run(cmd) == result) return true;
		SleepMS(WaitRepeat);
	}
	return false;
}

static std::string SWFAutomation_RunUntilNotEmpty(const char* cmd, int WaitTime, int WaitRepeat)
{
	for (int i = 0, iEnd = ((WaitTime+WaitRepeat-1) / WaitRepeat); i != iEnd; i++)
	{
		std::string res = SWFAutomation_Run(cmd);
		if (!res.empty()) return res;
		SleepMS(WaitRepeat);
	}
	return std::string();
}

//--------------------------------------------------------------------------------------------------------------------------------------

static sts_net_socket_t MozRepl_Socket;
static std::string MozRepl_MyId;

static bool MozRepl_ReadStream(std::string& Input, std::string* ResponseId = NULL)
{
	Input.clear();
	for (std::string::size_type nl, rid;;)
	{
		if (sts_net_check_socket(&MozRepl_Socket, 2.f) != 1 && (sts_net_send(&MozRepl_Socket, ";\n", 2) != 0 || sts_net_check_socket(&MozRepl_Socket, 28.f) != 1)) return false;
		char buf[1024], *p = buf;
		buf[sts_net_recv(&MozRepl_Socket, buf, sizeof(buf) - 8)] = '\0';
		//skip unprintable characters and occurences of MozRepl's intermediate output of "....> " (variable number of .)
		while (Input.empty() && ((*p && *p<=' ') || (*p=='.'&&p[1]=='.'&&p[2]=='.'&&strstr(p, "...> ")<p+4))) p = (*p=='.' ? strstr(p, "...> ") + 5 : p + 1);
		Input += p;
		if (Input.length() < 4 || Input[Input.length()-3] == '.' || Input[Input.length()-2] != '>' || Input[Input.length()-1] != ' ') continue;
		if ((nl = Input.rfind('\n')) == std::string::npos) rid = nl = 0; else rid = nl + 1;
		if (ResponseId) *ResponseId = Input.substr(rid, Input.length() - 2 - rid);
		while (nl && Input[nl-1] <= ' ' && Input[nl-1] >= 0) nl--;
		Input.resize(nl);
		return true;
	}
}

static std::string MozRepl_SendCmd(const char* cmd)
{
	std::string response, strcmd = cmd; //replace all occurences of "MOZREPL" with our repl object name
	Replace(strcmd, "MOZREPL", MozRepl_MyId.c_str());
	if (sts_net_send(&MozRepl_Socket, strcmd.c_str(), (int)strcmd.length()) < 0) return "!!! MOZREPL_ERROR Send error";
	else if (!MozRepl_ReadStream(response)) return (response.empty() ? std::string("!!! MOZREPL_ERROR timeout") : std::string("!!! MOZREPL_ERROR Recv Error - ") + response);
	return response;
}

static void MozRepl_ConsoleLog(const char* str)
{
	LogText("[CONSOLELOG] %s", str);
	std::string logstr = str;
	for (char *p = (logstr.empty() ? NULL : &logstr[0]), *pEnd = p + logstr.size() - 1; p != pEnd; p++) if (*p < 0x20 || *p > 0x7f) *p = '?'; else if (*p == '\'') *p = '"';
	static int lastlogrepeat;
	static std::string lastlogstr;
	if (lastlogstr == logstr) { lastlogrepeat++; return; }
	if (lastlogrepeat) { MozRepl_SendCmd(Format("window.content.eval('console.log(\\'%s ### Repeated %d more times\\')')", lastlogstr.c_str(), lastlogrepeat - 1).c_str()); lastlogrepeat = 0; }
	MozRepl_SendCmd(Format("window.content.eval('console.log(\\'%s\\')')", logstr.c_str()).c_str());
	lastlogstr = logstr;
}

static bool MozRepl_Connect(const char* Host, int Port)
{
	if (sts_net_init() < 0)
	{
		LogError("[MozRepl_Connect] Could not initialize networking - Aborting");
		return false;
	}
	LogText("[MozRepl_Connect] Connecting to %s:%d ...", Host, Port);
	if (sts_net_connect(&MozRepl_Socket, Host, Port) < 0)
	{
		LogError("[MozRepl_Connect] Could not connect to MozRepl on %s:%d - Aborting", Host, Port);
		return false;
	}
	LogText("[MozRepl_Connect] Connected! Reading welcome message ...");
	std::string WelcomeMessage;
	if (!MozRepl_ReadStream(WelcomeMessage, &MozRepl_MyId))
	{
		LogError("[MozRepl_Connect] No data received from MozRepl - Aborting");
		sts_net_close_socket(&MozRepl_Socket);
		return false;
	}
	LogText("[MozRepl_Connect] Success! Got repl object name: %s", MozRepl_MyId.c_str());
	return true;
}

static void MozRepl_Disconnect()
{
	sts_net_close_socket(&MozRepl_Socket);
}
