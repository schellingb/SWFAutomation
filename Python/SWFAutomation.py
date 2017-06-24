#--------------------------------------------#
# SWFAutomation                              #
# License: Public Domain (www.unlicense.org) #
#--------------------------------------------#

def main():
	if MozRepl_Connect('127.0.0.1', 4242) == False: exit(1)

	MozRepl_ConsoleLog(" 1. STARTING SWF AUTOMATION ...")
	SWFPageUrl = "http://www.adobe.com/devnet/actionscript/samples/interactivity_1.html"
	SWFElementJS = "document.getElementsByTagName('object')[0]"
	if SWFAutomation_Startup(SWFPageUrl, SWFElementJS) == False: exit(1)

	MozRepl_ConsoleLog(" 2. WAITING UNTIL PAGE IS LOADED AND SWF IS INITIALIZED ...")
	if SWFAutomation_RunUntilEqual("inj_active()", "true", 5) == False: exit(1)

	MozRepl_ConsoleLog(" 3. GETTING ATTRIBUTE beetle/shadow.scaleY: "                                       + SWFAutomation_Run("inj_get('beetle/shadow', 'scaleY')"))
	MozRepl_ConsoleLog(" 4. SETTING ATTRIBUTE beetle/shadow.scaleX TO 1.5: "                                + SWFAutomation_Run("inj_set('beetle/shadow', 'scaleX', 1.5)"))
	MozRepl_ConsoleLog(" 5. CALLING FUNCTION beetle.toString(); "                                           + SWFAutomation_Run("inj_call('beetle', 'toString')"))
	MozRepl_ConsoleLog(" 6. MOVING OBJECT beetle TO 300,80: "                                               + SWFAutomation_Run("inj_move('beetle', 300, 80)"))
	MozRepl_ConsoleLog(" 7. SENDING CLICK EVENT TO toggle_btn: "                                            + SWFAutomation_Run("inj_click('toggle_btn')"))
	MozRepl_ConsoleLog(" 8. GETTING STATIC ATTRIBUTE flash.system.System.totalMemory: "                     + SWFAutomation_Run("inj_static_get('flash.system.System', 'totalMemory')"))
	MozRepl_ConsoleLog(" 9. SETTING STATIC ATTRIBUTE flash.ui.Mouse.cursor TO 'hand': "                     + SWFAutomation_Run("inj_static_set('flash.ui.Mouse', 'cursor', 'hand')"))
	MozRepl_ConsoleLog("10. CALLING STATIC FUNCTION flash.external.ExternalInterface.call('eval', '4+3'): " + SWFAutomation_Run("inj_static_call('flash.external.ExternalInterface', 'call', 'eval', '4+3')"))

	MozRepl_ConsoleLog("11. CLEANING UP SWF AUTOMATION ...")
	SWFAutomation_Shutdown()

	MozRepl_ConsoleLog("12. DONE! Closing connection")
	MozRepl_Disconnect()

	exit(0)

#--------------------------------------------------------------------------------------------------------------------------------------

import sys,socket,time

def SWFAutomation_Startup(url, SetElementJS = "document.getElementsByTagName('embed')[0]||document.getElementsByTagName('object')[0]"):
	#this loops through all open windows/tabs to find an open tab to the requested url and if not found opens a new tab to it - then it returns the window handle to the window showing that tab
	MozHWND = MozRepl_SendCmd(
		"MOZREPL.print((function()"
		"{"
			"MOZREPL.se = \"if (!this.swae) try{ swae = " + SetElementJS.replace('"',"'") + "; }catch(e){}\";"
			"var tab, w, url = '" + url + "', e = Components.classes['@mozilla.org/appshell/window-mediator;1'].getService(Ci.nsIWindowMediator).getEnumerator(null);"
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
		"})());")

	if len(MozHWND) < 3 or MozHWND[0] != '0' or MozHWND[1] != 'x': #should start with 0x
		sys.stderr.write("[SWFAutomation_Startup] Could not set up SWF Automation - Error: " + MozHWND + "\n")
		return False

	return True

def SWFAutomation_Shutdown():
	MozRepl_SendCmd("(function(){delete MOZREPL.w;delete MOZREPL.se;return 1;})();")

def SWFAutomation_Run(cmd):
	res = MozRepl_SendCmd("MOZREPL.print(MOZREPL.w.eval(MOZREPL.se + '(this.swae&&swae.inj_get?swae." + cmd.replace("'", "\\'") + ":\\'SWFAUTO_ERROR\\')'))")
	#MozRepl_ConsoleLog("[SWFAUTOMATION] swae." + cmd + " ==> [" + res + "]") #debug
	return res

def SWFAutomation_RunUntilEqual(cmd, result, WaitTime = 0.8, WaitRepeat = 0.05):
	for i in xrange(0, int((WaitTime+WaitRepeat-1) / WaitRepeat)):
		if SWFAutomation_Run(cmd) == result: return True
		time.sleep(WaitRepeat)
	return False

def SWFAutomation_RunUntilNotEmpty(cmd, WaitTime = 0.8, WaitRepeat = 0.05):
	for i in xrange(0, int((WaitTime+WaitRepeat-1) / WaitRepeat)):
		res = SWFAutomation_Run(cmd)
		if res != '': return res
		time.sleep(WaitRepeat)
	return ''

#--------------------------------------------------------------------------------------------------------------------------------------

def MozRepl_ReadStream():
	global MozRepl_Socket, MozRepl_MyId
	Input = ''
	while True:
		MozRepl_Socket.settimeout(2)
		try: buf = MozRepl_Socket.recv(1024)
		except:
			MozRepl_Socket.send(";\n")
			MozRepl_Socket.settimeout(28)
			try: buf = MozRepl_Socket.recv(1024)
			except: return "!!! MOZREPL_ERROR timeout - " + Input
		while len(Input) == 0 and len(buf) > 0:
			#skip unprintable characters and occurences of MozRepl's intermediate output of "....> " (variable number of .)
			if ord(buf[0]) > 0 and ord(buf[0]) <= 32: buf = buf[1:]
			elif buf[:3] == "..." and buf[:8].count("...> ") == 1: buf = buf[buf.find("...> ")+5:]
			else: break
		Input += buf
		if len(Input) < 4 or Input[-3] == '.' or Input[-2] != '>' or Input[-1] != ' ': continue
		nl = Input.rfind('\n')
		if nl == -1: rid = nl = 0
		else: rid = nl + 1
		if MozRepl_MyId == '': MozRepl_MyId = Input[rid:-2]
		while nl > 0 and ord(Input[nl-1]) <= 32: nl-=1
		return Input[:nl]

def MozRepl_SendCmd(cmd):
	global MozRepl_Socket, MozRepl_MyId
	#replace all occurences of "MOZREPL" with our repl object name
	if MozRepl_Socket.send(cmd.replace("MOZREPL", MozRepl_MyId)) < 0: return "!!! MOZREPL_ERROR Send error"
	return MozRepl_ReadStream()

def MozRepl_ConsoleLog(LogStr):
	global MozRepl_Socket, MozRepl_LastLogRepeat, MozRepl_LastLogStr
	print "[CONSOLELOG]", LogStr
	LogStr = ''.join(['?' if ord(i) < 0x20 or ord(i) > 0x7f else '"' if i == "'" else i for i in LogStr])
	if MozRepl_LastLogStr == LogStr: MozRepl_LastLogRepeat += 1; return
	if MozRepl_LastLogRepeat > 0: MozRepl_SendCmd("window.content.eval('console.log(\\'" + MozRepl_LastLogStr + " ### Repeated " + str(MozRepl_LastLogRepeat - 1) + " more times\\')')"); MozRepl_LastLogRepeat = 0
	MozRepl_SendCmd("window.content.eval('console.log(\\'" + LogStr + "\\')')")
	MozRepl_LastLogStr = LogStr

def MozRepl_Connect(Host, Port):
	global MozRepl_Socket, MozRepl_MyId, MozRepl_LastLogRepeat, MozRepl_LastLogStr
	print "[MozRepl_Connect] Connecting to " + Host + ":" + str(Port) + " ..."
	MozRepl_Socket = socket.socket()
	try: MozRepl_Socket.connect((Host, Port))
	except:
		sys.stderr.write("[MozRepl_Connect] Could not connect to MozRepl on " + Host + ":" + str(Port) + " - Aborting\n")
		return False
	print "[MozRepl_Connect] Connected! Reading welcome message ..."
	MozRepl_LastLogRepeat = 0
	MozRepl_LastLogStr = ""
	MozRepl_MyId = ""
	WelcomeMessage = MozRepl_ReadStream()
	if WelcomeMessage == "" or WelcomeMessage[0] == "!" or MozRepl_MyId == "":
		sys.stderr.write("[MozRepl_Connect] No data received from MozRepl - Aborting\n")
		MozRepl_Socket.close()
		return False
	print "[MozRepl_Connect] Success! Got repl object name: " + MozRepl_MyId
	return True

def MozRepl_Disconnect():
	global MozRepl_Socket
	MozRepl_Socket.close()

#--------------------------------------------------------------------------------------------------------------------------------------

if __name__ == "__main__": main()
