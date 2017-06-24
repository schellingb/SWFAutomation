;--------------------------------------------;
; SWFAutomation                              ;
; License: Public Domain (www.unlicense.org) ;
;--------------------------------------------;

#Persistent
#SingleInstance Force
CoordMode,Mouse,Screen

MOZREPL_PORT = 4242
MOZREPL_HOST = 127.0.0.1
SWF_PRELOAD := "..\SWFAutomationPreload.swf"

if (!MozRepl_LoadCurl())
{
	MsgBox,16,Error,Could not load curl
	ExitApp
}
if (!FileExist(GetAbsolutePath(SWF_PRELOAD)))
{
	MsgBox,16,Error,Could not find swf preloader %SWF_PRELOAD%
	ExitApp
}

;------------------------------------------------------------------------------------------------------------------

MozRepl_ConsoleLog(" 1. STARTING SWF AUTOMATION ...")
SWFAutomation_Startup("http://www.adobe.com/devnet/actionscript/samples/interactivity_1.html", "document.getElementsByTagName('object')[0]")

MozRepl_ConsoleLog(" 2. WAITING UNTIL PAGE IS LOADED AND SWF IS INITIALIZED ...")
SWFAutomation_RunUntilEqual("inj_active()", "true", 5000)

MozRepl_ConsoleLog(" 3. GETTING ATTRIBUTE beetle/shadow.scaleY: "                                       . SWFAutomation_Run("inj_get('beetle/shadow', 'scaleY')"))
MozRepl_ConsoleLog(" 4. SETTING ATTRIBUTE beetle/shadow.scaleX TO 1.5: "                                . SWFAutomation_Run("inj_set('beetle/shadow', 'scaleX', 1.5)"))
MozRepl_ConsoleLog(" 5. CALLING FUNCTION beetle.toString(); "                                           . SWFAutomation_Run("inj_call('beetle', 'toString')"))
MozRepl_ConsoleLog(" 6. MOVING OBJECT beetle TO 300,80: "                                               . SWFAutomation_Run("inj_move('beetle', 300, 80)"))
MozRepl_ConsoleLog(" 7. SENDING CLICK EVENT TO toggle_btn: "                                            . SWFAutomation_Run("inj_click('toggle_btn')"))
MozRepl_ConsoleLog(" 8. GETTING STATIC ATTRIBUTE flash.system.System.totalMemory: "                     . SWFAutomation_Run("inj_static_get('flash.system.System', 'totalMemory')"))
MozRepl_ConsoleLog(" 9. SETTING STATIC ATTRIBUTE flash.ui.Mouse.cursor TO 'hand': "                     . SWFAutomation_Run("inj_static_set('flash.ui.Mouse', 'cursor', 'hand')"))
MozRepl_ConsoleLog("10. CALLING STATIC FUNCTION flash.external.ExternalInterface.call('eval', '4+3'): " . SWFAutomation_Run("inj_static_call('flash.external.ExternalInterface', 'call', 'eval', '4+3')"))

MozRepl_ConsoleLog("11. CLEANING UP SWF AUTOMATION ...")
SWFAutomation_Shutdown()

MozRepl_ConsoleLog("12. DONE!")
ExitApp

;------------------------------------------------------------------------------------------------------------------

SWFAutomation_Startup(url, SetElementJS = "document.getElementsByTagName('embed')[0]||document.getElementsByTagName('object')[0]")
{
	global StartMouseX, StartMouseY, SWF_PRELOAD, gWasAborted
	gWasAborted := false
	MouseGetPos,StartMouseX,StartMouseY

	;This sets the preload swf to be used by flash to allow automation
	FileRead, file, %A_Desktop%\..\mm.cfg
	if (!InStr(file, "`nPreloadSwf=" . GetAbsolutePath(SWF_PRELOAD) . "`n"))
	{
		file := FileOpen(A_Desktop . "\..\mm.cfg", "w")
		file.Write("SuppressDebuggerExceptionDialogs=1`nAllowUserLocalTrust=1`nAutoUpdateDisable=1`nDisableProductDownload=1`nErrorReportingEnable=0`nPolicyFileLog=0`nTraceOutputFileEnable=0`nPreloadSwf=" . GetAbsolutePath(SWF_PRELOAD) . "`n")
		file.Close()
		;TODO: NEED TO KILL/RESTART plugin-container.exe TO ACTUALLY APPLY NEW mm.cfg SETTINGS (ONLY WHEN mm.cfg WAS MODIFIED)!!
	}

	gethwndcmd = ;this loops through all open windows/tabs to find an open tab to the requested url and if not found opens a new tab to it - then it returns the window handle to the window showing that tab
	( LTrim
		MOZREPL.print((function()
		{
			MOZREPL.se = "if (!this.swae) try{ swae = %SetElementJS%; }catch(e){}";
			var tab, w, url = '%url%', e = Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Ci.nsIWindowMediator).getEnumerator(null);
			while (!tab && e && (w = e.getNext()))
			{
				for (var nodes = w.getBrowser().tabContainer.childNodes, i = 0; !tab && i < nodes.length; i++)
				{
					var cw = nodes[i].linkedBrowser.contentWindow, loc = cw.location, href = loc.href, doc = cw.document;
					if (href != url) continue;
					tab = nodes[i];
					var ret = cw.eval(MOZREPL.se + 'this.swae?swae.inj_get?2:1:0');
					if (ret == 0) { if (doc.body) doc.body.innerHTML = ''; loc.href = url; }
					if (ret == 1) cw.eval('swae = swae.parentElement;swaehtml = swae.innerHTML;swae.innerHTML = swaehtml;delete swaehtml;delete swae');
				}
			}
			if (!tab) w = (getBrowser().addTab ? this : Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Ci.nsIWindowMediator).getEnumerator(null).getNext());
			if (!tab) tab = w.getBrowser().addTab(url);
			MOZREPL.w = tab.linkedBrowser.contentWindow;
			w.getBrowser().selectedTab = tab;
			return w.getInterface(Ci.nsIWebNavigation).QueryInterface(Ci.nsIDocShellTreeItem).treeOwner.nsIBaseWindow.nativeHandle;
		})());
	)
	MozHWND := MozRepl_SendCmd(RegExReplace(gethwndcmd, "`n", ""))
	if (Instr(MozHWND, "!!!") || MozHWND = "" || MozHWND = "0" || SubStr(MozHWND, 1, 2) != "0x")
	{
		MsgBox,16,SWFAutomation,Could not set up SWF Automation - Error: %MozHWND%
		gWasAborted = true
		return false
	}
	WinActivate,ahk_id %MozHWND%
}

SWFAutomation_Shutdown()
{
	MozRepl_SendCmd("(function(){delete MOZREPL.w;delete MOZREPL.se;return;})();1;")
	;;Reverting mm.cfg (can't be done easily as setting PreloadSwf again would require browser restart in most cases for now)
	;file := FileOpen(A_Desktop . "\..\mm.cfg", "w")
	;file.Write("SuppressDebuggerExceptionDialogs=1`nAllowUserLocalTrust=1`nAutoUpdateDisable=1`nDisableProductDownload=1`nErrorReportingEnable=0`nPolicyFileLog=0`nTraceOutputFileEnable=0`n")
	;file.Close()
}

DidAbort()
{
	global gWasAborted
	if (gWasAborted)
		return true
	global StartMouseX, StartMouseY
	MouseGetPos,CurrentX,CurrentY
	if (CurrentX == StartMouseX && CurrentY == StartMouseY)
		return false
	if ((((CurrentX-StartMouseX)*(CurrentX-StartMouseX))+((CurrentY-StartMouseY)*(CurrentY-StartMouseY))) < 20)
		return false
	global DidMouseMoveResult
	DidMouseMoveResult := "Mouse Moved From " . StartMouseX . "," . StartMouseY . " to " . CurrentX . "," . CurrentY . "!!"
	MozRepl_ConsoleLog("[DidAbort] Mouse Moved From " . StartMouseX . "," . StartMouseY . " to " . CurrentX . "," . CurrentY . "!!")
	gWasAborted := true
	return true
}

SWFAutomation_Run(cmd)
{
	global gWasAborted
	if (gWasAborted)
		return "SWFAUTO_ERROR"
	res := MozRepl_SendCmd("MOZREPL.print(MOZREPL.w.eval(MOZREPL.se + '(this.swae&&swae.inj_get?swae." . RegExReplace(cmd, "'", "\'") . ":\'SWFAUTO_ERROR\')'))")
	;MozRepl_ConsoleLog("[SWFAUTOMATION_RUN] swae." . cmd . " ==> [" . res . "]") ;debug
	return res
}

SWFAutomation_RunUntilEqual(cmd, result, WaitTime := 800, WaitRepeat := 50)
{
	Loop, % ((WaitTime+WaitRepeat-1) // WaitRepeat)
	{
		if (SWFAutomation_Run(cmd) == result)
			return true
		Sleep WaitRepeat
		If (DidAbort())
			return false
	}
	return false
}

SWFAutomation_RunUntilNotEmpty(cmd, WaitTime := 800, WaitRepeat := 50)
{
	Loop, % ((WaitTime+WaitRepeat-1) // WaitRepeat)
	{
		res := SWFAutomation_Run(cmd)
		if (res)
			return res
		Sleep WaitRepeat
		If (DidAbort())
			return false
	}
	return false
}

;------------------------------------------------------------------------------------------------------------------

MozRepl_DownloadURL(url)
{
	MozRepl_SendCmd("MOZREPL.x = new XMLHttpRequest();MOZREPL.x.open('get', '" . url . "', true);MOZREPL.x.send();")
	Loop, 200
	{
		Sleep 30
		If (MozRepl_SendCmd("MOZREPL.x.status") != 0)
			break
	}
	DATA := MozRepl_SendCmd("MOZREPL.print(MOZREPL.x.response);")
	MozRepl_SendCmd("delete MOZREPL.x")
	return DATA	
}

MozRepl_ConsoleLog(logtext)
{
	global gWasAborted
	if (gWasAborted)
		return
	ListLines Off
	static lastlogtext, lastlogrepeat
	if (logtext == lastlogtext)
	{
		lastlogrepeat++
		return
	}
	if (lastlogrepeat)
	{
		MozRepl_SendCmd("window.content.eval('console.log(\'" . RegExReplace(RegExReplace(lastlogtext, "[^\x{20}-\x{7F}]", "?"), "'", "\\\'") . " ### Repeated " . (lastlogrepeat - 1) . " more times\')')")
		lastlogrepeat := 0
	}
	lastlogtext := logtext
	MozRepl_SendCmd("window.content.eval('console.log(\'" . RegExReplace(RegExReplace(logtext, "[^\x{20}-\x{7F}]", "?"), "'", "\\\'") . "\')')")
	ListLines On
}

MozRepl_LoadCurl()
{
	global REPLCurlDLL, REPLCurlSend, REPLCurlRecv
	REPLCurlDLL := "LIBCURL" . (A_PtrSize == 8 ? "64" : "32")
	hModule := DllCall("LoadLibrary", "Str", A_ScriptDir . "\" REPLCurlDLL . ".DLL", "Ptr")
	
	REPLCurlSend := DllCall("GetProcAddress", Ptr, hModule, AStr, "curl_easy_send", "Ptr")
	REPLCurlRecv := DllCall("GetProcAddress", Ptr, hModule, AStr, "curl_easy_recv", "Ptr")
	ret := DllCall(REPLCurlDLL . "\curl_global_init", "UInt", 3, "CDecl")
	;MsgBox REPLCurlDLL = %REPLCurlDLL% - hModule = %hModule% - ret = %ret% - ErrorLevel = %ErrorLevel% - Dir = %A_ScriptDir% - REPLCurlSend = %REPLCurlSend% - REPLCurlRecv = %REPLCurlRecv%
	If (!hModule || ret == "" || ret || !REPLCurlSend || !REPLCurlRecv)
	{
		MsgBox,16,Error,Unable to load LibCurl - REPLCurlDLL = %REPLCurlDLL% - hModule = %hModule% - ret = %ret% - ErrorLevel = %ErrorLevel% - Dir = %A_ScriptDir%
		return false
	}
	return true
}

MozRepl_Connect()
{
	global REPLCurlDLL, REPLCurlHandle, REPLPrompt, MOZREPL_HOST, MOZREPL_PORT
	
	if (REPLCurlHandle)
		DllCall(REPLCurlDLL . "\curl_easy_cleanup", "UInt", REPLCurlHandle, "CDecl")
	
	REPLCurlHandle := DllCall(REPLCurlDLL . "\curl_easy_init")
	DllCall(REPLCurlDLL . "\curl_easy_setopt", "UInt", REPLCurlHandle, "UInt", 141, "UInt", true, "CDecl") ;CURLOPT_CONNECT_ONLY
	DllCall(REPLCurlDLL . "\curl_easy_setopt", "UInt", REPLCurlHandle, "UInt", 10002, "AStr", MOZREPL_HOST . ":" . MOZREPL_PORT, "CDecl") ;CURLOPT_URL
	ret := DllCall(REPLCurlDLL . "\curl_easy_perform", "UInt", REPLCurlHandle, "CDecl")
	if (ret == "" || ret)
	{
		DllCall(REPLCurlDLL . "\curl_easy_cleanup", "UInt", REPLCurlHandle, "CDecl")
		REPLCurlHandle =
		MsgBox,16,Error,Could not connect to FireFox - Curl error code: %ret% - Host: %MOZREPL_HOST% - Port: %MOZREPL_PORT% - REPLCurlHandle: %REPLCurlHandle%
		return false
	}
	REPLPrompt := ""
	Incoming := ""
	Loop
	{
		VarSetCapacity(Buffer, 4096)
		Bytes := 0
		DllCall(REPLCurlDLL . "\curl_easy_recv" ,"UInt" ,REPLCurlHandle,"UInt", &Buffer,"UInt" ,4095, "UInt*", Bytes, "CDecl")
		IfEqual,Bytes,0,continue
		Incoming .= StrGet(&Buffer, Bytes, "UTF-8")
		LastNL := InStr(Incoming, "`n", true, -4)
		;MsgBox % "RECV [" . StrGet(&Buffer, Bytes, "UTF-8") . "] BYTES [" . Bytes . "] - LastNL [" . LastNL . "] - REPLPrompt [" . SubStr(Incoming, LastNL+1, -2) . "]"
		If (SubStr(Incoming, -1) == "> " && LastNL > 0 && SubStr(Incoming, LastNL+1, 4) == "repl")
			REPLPrompt := SubStr(Incoming, LastNL+1, -2)
		IfNotEqual,REPLPrompt,,break
	}
	if (!REPLPrompt)
	{
		REPLCurlHandle =
		MsgBox,16,Error,Could not connect to FireFox - Data received from MozRepl: %Incoming%
		return false
	}
	return true
}

MozRepl_SendCmd(cmd)
{
	ListLines Off
	global REPLCurlHandle, REPLCurlSend, ReplCurlRecv, REPLPrompt
	Incoming := ""
	if (!REPLCurlHandle && !MozRepl_Connect())
	{
		Incoming := "!!! MOZREPL_ERROR Can't connect"
		goto DoneSendCmd
	}

	ReTrySendCmd:
	sendcmd := RegExReplace(cmd, "MOZREPL", REPLPrompt) . "`n"
	granted := VarSetCapacity(Buffer, StrPut(sendcmd, "UTF-8"))
	buflen := StrPut(sendcmd, &Buffer, strlen(sendcmd), "UTF-8")
	Bytes := 0
	ret := DllCall(REPLCurlSend, "UInt", REPLCurlHandle, "UInt", &Buffer, "UInt", buflen, "UInt*", Bytes, "CDecl")
	if (ret)
	{
		MsgBox % "MozRepl ERROR!`n-----------------------------------------`nTRIED TO SEND [" . sendcmd . "]`nRETURN ERROR CODE [" . ret . "]"
		if (MozRepl_Connect())
			goto ReTrySendCmd
		Incoming := "!!! MOZREPL_ERROR Send error"
		goto DoneSendCmd
	}

	Loop
	{
		VarSetCapacity(Buffer, 4096)
		Bytes := 0
		ret := DllCall(ReplCurlRecv ,"UInt" ,REPLCurlHandle,"UInt", &Buffer,"UInt" ,4095, "UInt*", Bytes, "CDecl")
		if (ret = 56)
		{
			if (MozRepl_Connect())
				goto ReTrySendCmd
			Incoming := "!!! MOZREPL_ERROR Receive error"
			break
		}
		if (ret = 81) ;81 means no data available now, add sleep and repeat only 10 times or so then show response timeout error
		{
			Sleep 100
			if (A_Index == 10)
			{
				buflen := StrPut(";`n", &Buffer, 2, "UTF-8")
				DllCall(REPLCurlSend, "UInt", REPLCurlHandle, "UInt", &Buffer, "UInt", buflen, "UInt*", Bytes, "CDecl")
			}
			IfLessOrEqual,A_Index,15,continue
			Incoming := "!!! MOZREPL_ERROR timeout, data so far: [" + Incoming + "]"
			break
		}
		if (ret != 0)
		{
			Incoming := "!!! MOZREPL_ERROR Recv Error " . ret . " - Incoming [" . Incoming . "] - Bytes [" . Bytes . "]"
			break
		}
		IfEqual,Bytes,0,continue
		Incoming .= StrGet(&Buffer, Bytes, "UTF-8")
		If (SubStr(Incoming, -1-StrLen(REPLPrompt)) == REPLPrompt . "> ")
			break
	}
	
	DoneSendCmd:
	if (InStr(Incoming, "!!! ") || !InStr(Incoming, REPLPrompt . ">"))
	{
		MsgBox % "MozRepl JAVA SCRIPT ERROR!`n-----------------------------------------`nSENT [" . sendcmd . "]`nRECEIVED [" . Incoming . "]"
	}
	
	ListLines On
	return Substr(RegExReplace(Incoming, "(\.\.\.\.?\.?\.?|" . REPLPrompt . ")> ", ""), 1, -1)
}

GetAbsolutePath(p)
{
	StringReplace, p, p, /,\
	p := (SubStr(p,2,1) = ":" ? p : (SubStr(p,1,1) = "\" ? SubStr(A_ScriptDir,1,2) . p : A_ScriptDir . "\" . p))
	return RegExReplace(p, "\\[^\\]*\\\.\.", "")
}
