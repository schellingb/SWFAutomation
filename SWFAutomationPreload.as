package
{
	import flash.display.*;
	import flash.events.*;
	import flash.system.Security;
	import flash.external.ExternalInterface;
	import flash.geom.Point;

	public class SWFAutomationPreload extends Sprite 
	{
		private var loaderstage:Stage;
		private var loaderdomain:flash.system.ApplicationDomain;

		public function SWFAutomationPreload():void 
		{
			//mylog('[SWFAutomationPreload]');
			if (!ExternalInterface.available) return;
			if (loaderInfo.parameters.hasOwnProperty('object_filter') && ExternalInterface.objectID.indexOf(loaderInfo.parameters['object_filter']) < 0) return;
			ExternalInterface.addCallback("inj_active", function():Boolean { return !!loaderstage });
			if (stage) init(); else addEventListener(Event.ADDED_TO_STAGE, init);
		}

		private function init(e:Event = null):void 
		{
			//mylog('[init]');
			if (e) removeEventListener(Event.ADDED_TO_STAGE, init);
			stage.addEventListener("allComplete", allCompleteHandlerMain);
			addEventListener("allComplete", allCompleteHandlerMain);
		}

		private function allCompleteHandlerMain(e:Event):void 
		{
			//mylog('[allCompleteHandlerMain]');
			if (!e || !e.target || !(e.target is LoaderInfo)) { mylog('[allCompleteHandlerMain] NO TARGET ' + e.target); return; }
			if (!e.target.url) { /*mylog('[allCompleteHandlerMain] NO URL ' + e.target + ' (loaderURL: ' + e.target.loaderURL + ')');*/ return; }
			try
			{
				var loader:LoaderInfo = (e.target as LoaderInfo);
				if (!loader.content) { mylog('[allCompleteHandlerMain] NO CONTENT IN TARGET ' + e.target + '(url: ' + e.target.url + ' - loaderURL: ' + e.target.loaderURL + ')'); return; }
				if (!loader.content.stage) { /*mylog('[allCompleteHandlerMain] NO STAGE IN TARGET ' + e.target + '(url: ' + e.target.url + ' - loaderURL: ' + e.target.loaderURL + ')');*/ return; }
			}
			catch (ex:*) { mylog('[allCompleteHandlerMain] EXCEPTION IN TARGET ' + e.target + '(url: ' + e.target.url + ' - loaderURL: ' + e.target.loaderURL + ') [' + ex + '][' + ex.getStackTrace() + ']'); return; }
			if (loader.content.stage == loaderstage) { /*mylog('[allCompleteHandlerMain] SKIPPING ' + loader.url + ' (BY ' + loader.loaderURL + ' )');*/ return; }
			loaderstage = loader.content.stage;
			loaderdomain = loader.applicationDomain;
			Security.allowDomain("*");
			ExternalInterface.addCallback("inj_click",       inj_click);
			ExternalInterface.addCallback("inj_mousedownup", inj_mousedownup);
			ExternalInterface.addCallback("inj_move",        inj_move);
			ExternalInterface.addCallback("inj_get",         inj_get);
			ExternalInterface.addCallback("inj_set",         inj_set);
			ExternalInterface.addCallback("inj_call",        inj_call);
			ExternalInterface.addCallback("inj_static_get",  inj_static_get);
			ExternalInterface.addCallback("inj_static_set",  inj_static_set);
			ExternalInterface.addCallback("inj_static_call", inj_static_call);
			CONFIG::interactive { debug_setup(); }
			mylog('[allCompleteHandlerMain] ADDED CALLBACKS TO ' + e.target + '(url: ' + e.target.url + ' - loaderURL: ' + e.target.loaderURL + ')');
		}

		private function inj_click(path:String):Boolean
		{
			var c:DisplayObject = FindObjectByNamePath(path);
			return (c  ? c.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false, 10, 10)) : false);
		}

		private function inj_mousedownup(path:String):Boolean
		{
			var c:DisplayObject = FindObjectByNamePath(path);
			return (c ? c.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN, true, false, 10, 10)) && c.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP, true, false, 10, 10)) : false);
		}

		private function inj_move(path:String, x:Number, y:Number):Boolean
		{
			var findchild:DisplayObject = FindObjectByNamePath(path);
			if (!findchild) return false;
			var ptxylocal:Point = findchild.parent.globalToLocal(new Point(x, y));
			findchild.x = ptxylocal.x;
			findchild.y = ptxylocal.y;
			return true;
		}

		private function inj_get(path:String, ...attribnames):*
		{
			var o:* = FindObjectByNamePath(path), i:int=0;
			try { while (i<attribnames.length) o = o[attribnames[i++]]; return o; } catch (e:*) { /* mylog('ERR[' + e + ']'); */ } return null;
		}

		private function inj_set(path:String, ...attribsvalue):Boolean
		{
			var o:* = FindObjectByNamePath(path), i:int=0;
			try { while (i<attribsvalue.length-2) o = o[attribsvalue[i++]]; o[attribsvalue[i]] = attribsvalue[i+1]; return true; } catch (e:*) { /* mylog('ERR[' + e + ']'); */ } return false;
		}

		private function inj_call(path:String, ...attribsparams):*
		{
			try { var o:* = FindObjectByNamePath(path), i:int=attribsparams.length, f:*;
			while (i--) { f = attribsparams.shift(); if (o[f] is Function) return o[f].apply(o, attribsparams); else o = o[f]; } } catch (e:*) { /* mylog('ERR[' + e + ']'); */ } return null;
		}

		private function inj_static_get(classname:String, ...attribnames):*
		{
			try { var o:* = loaderdomain.getDefinition(classname), i:int=0;
			while (i<attribnames.length) o = o[attribnames[i++]]; return o; } catch (e:*) { /* mylog('ERR[' + e + ']'); */ } return null;
		}

		private function inj_static_set(classname:String, ...attribsvalue):Boolean
		{
			try { var o:* = loaderdomain.getDefinition(classname), i:int=0;
			while (i<attribsvalue.length-2) o = o[attribsvalue[i++]]; o[attribsvalue[i]] = attribsvalue[i+1]; return true; } catch (e:*) { /* mylog('ERR[' + e + ']'); */ } return false;
		}

		private function inj_static_call(classname:String, ...attribsparams):*
		{
			try { var o:* = loaderdomain.getDefinition(classname), i:int=attribsparams.length, f:*;
			while (i--) { f = attribsparams.shift(); if (o[f] is Function) return o[f].apply(o, attribsparams); else o = o[f]; } } catch (e:*) { /* mylog('ERR[' + e + ']'); */ } return null;
		}

		private function FindObjectByNamePath(path:String):DisplayObject
		{
			var findchild:DisplayObject, cont:DisplayObjectContainer = loaderstage;
			for (var parts:* = path.split('/'), i:int = 0; i < parts.length; i++)
			{
				findchild = (parts[i].match(/^\d+$/) ? (int(parts[i]) >= 0 && int(parts[i]) < cont.numChildren ? cont.getChildAt(int(parts[i])) : null) : FindRecursive(cont, parts[i]));
				if (findchild) cont = findchild as DisplayObjectContainer; else return null;
			}
			return findchild
		}

		private function FindRecursive(cont:DisplayObjectContainer, name:String, recurse:int = 0):DisplayObject
		{
			if (!cont) return null;
			var res:DisplayObject = FindRecursiveIn(cont, name, recurse);
			if (!res && recurse < 8) { return FindRecursive(cont, name, recurse + 1); }
			return res;
		}

		private function FindRecursiveIn(cont:DisplayObjectContainer, name:String, recurse:int = 0):DisplayObject
		{
			for (var i:int = 0; i < cont.numChildren; i++)
			{
				var child:DisplayObject = cont.getChildAt(i);
				if (child && child.name == name) return child;
				var childcont:DisplayObjectContainer = child as DisplayObjectContainer;
				if (childcont && recurse) { child = FindRecursiveIn(childcont, name, recurse - 1); if (child) return child; }
			}
			return null;
		}

		private function mylog(t:String):void
		{
			ExternalInterface.call('eval', 'console.log(unescape(\'' + escape(t).replace(/\./g, "%2E").replace(/\:/g, "%3A").replace(/\//g, "%2F").replace(/\*/g, "%2A")
				.replace(/\+/g, "%2B").replace(/\-/g, "%2D").replace(/\@/g, "%40").replace(/\_/g, "%5F") + '\'))');
		}

		CONFIG::interactive
		{
			import flash.geom.Rectangle;
			import flash.utils.*;
			import mx.utils.StringUtil;
			private var rec:Sprite;

			private function debug_setup():void
			{
				var btn:Sprite = new Sprite();
				btn.graphics.lineStyle(3, 0x00CCFF);
				btn.graphics.beginFill(0x00CCFF);
				btn.graphics.drawRect(10, 10, 10, 10);
				btn.graphics.drawRect(10, 25, 10, 10);
				btn.graphics.drawRect(10, 40, 10, 10);
				btn.addEventListener(MouseEvent.CLICK, debug_click);
				loaderstage.addChild(btn);
			}

			private function debug_click(event:MouseEvent):void
			{
				loaderstage.removeChild(event.target as DisplayObject);
				if (!rec) { rec = new Sprite(); rec.graphics.lineStyle(3, 0x00CCFF); loaderstage.addChild(rec); ExternalInterface.addCallback("plsdbg", plsdbg); }
				ExternalInterface.call('eval', '(function(){'
					+	'plss = document.getElementById("' + ExternalInterface.objectID + '");'
					+	'if (!this.plss) plss = document.getElementsByTagName("embed")[0];'
					+	'if (!this.plss) plss = document.getElementsByTagName("object")[0];'
					+	'if (this.plss && !this.plsd) plsd = plss.parentElement.appendChild(document.createElement("div"));'
					+	'if (this.plsd)'
					+	'{'
					+		'plsd.style.position = "absolute";'
					+		'plsd.style.left = plss.offsetLeft + plss.offsetWidth + "px";'
					+		'plsd.style.top = plss.offsetTop + "px";'
					+		'plsd.style.width = "1024px";'
					+		'plsd.style.height = plss.offsetHeight + "px";'
					+		'plsd.style.backgroundColor = "white";'
					+		'plsd.style.overflow = "scroll";'
					+		'plsd.innerHTML = plss.plsdbg("S");'
					+		'plss.onmousedown = function(e) { if (e.shiftKey) document.getElementById("X_S").innerHTML = plss.plsdbg("S$"+e.offsetX+"$"+e.offsetY,30); };'
					+	'}'
					+'})();');
			}

			private function htmlFor(o:*, i:int, totcount:int, thispath:String):String
			{
				var c:DisplayObject = (o as DisplayObject);
				if (c)
				{
					if (c == rec) return '';
					var io:InteractiveObject = c as InteractiveObject;
					var cont:DisplayObjectContainer = c as DisplayObjectContainer;
					return ''
						+(cont ? '[<a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'\', 0)">+</a>]' : '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;')
						+' [<a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'\', 1)">-</a>]'
						+' [' + i + '/' + totcount + '] [' + thispath + '] ' + c.name + ' @ ' + c.x+','+c.y+','+c.width+','+c.height
						+' - <a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'\', 2)">' + c + '</a>'
						+' [<a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'\', 3)">CLICK</a>]'
						+' [<a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'\', 4)">VIS</a>]'
						+(thispath == 'S' ? ' [<a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'$\'+window.prompt(\'NAME\'), 10)">FIND</a>]' : '')
						+(thispath == 'S' ? ' [<a href="javascript://" onclick="document.getElementById(\'X_'+thispath+'\').innerHTML = plss.plsdbg(\''+thispath+'$\'+window.prompt(\'CLASS\'), 20)">DUMP</a>]' : '')
						+(io && io.mouseEnabled ? ' [MOUSE]' : '')
						+'<div id="X_'+thispath+'" style="padding-left:30px"></div>';
				}
				return o;
			}

			private function plsdbg(input:String,listtype:int = -1):String
			{
				var params:* = input.split('$');
				var parts:* = params[0].split(':');
				var base:String = parts.shift();
				var o:DisplayObject;
				try { if (base == "S") o = loaderstage; } catch (e:*) { return 'ERR[' + e + ']'; }

				var i:int;
				var cont:DisplayObjectContainer;
				for (i = 0; i < parts.length; i++) o = (o as DisplayObjectContainer).getChildAt(uint(parts[i]));

				var bounds:Rectangle = GetFixedRect(o);
				rec.graphics.clear();
				rec.graphics.lineStyle(3, 0x00CCFF);
				rec.graphics.drawRect(bounds.x, bounds.y, bounds.width, bounds.height);

				var res:String = '';

				if (listtype == -1) //show single line info about self
				{
					res = htmlFor(o, 0, 0, params[0]);
				}
				if (listtype == 0) //show children
				{
					cont = o as DisplayObjectContainer;
					if (cont == null) return '** ERROR **';
					for (i = 0; i < cont.numChildren; i++)
					{
						res += htmlFor(cont.getChildAt(i), i, cont.numChildren, params[0] + ':' + i);
					}
				}
				if (listtype == 1) //show nothing (just draw bounds)
				{
				}
				if (listtype == 2) //dump object
				{
					res = dumpobj(o).replace(/\n/g,'<br>').replace(/  /g,'&nbsp; ');
				}
				if (listtype == 3) //send click event
				{
					try { o.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false)); } catch (e:*) { res += 'CLICKERR[' + e + ']'; }
				}
				if (listtype == 4) //toggle visibility
				{
					o.visible = !o.visible;
				}
				if (listtype == 10) //find children and sub-children by names
				{
					cont = o as DisplayObjectContainer;
					if (cont == null) return '** ERROR **';
					parts = params[1].split('/');
					for (i = 0; i < parts.length; i++)
					{
						var findchild:DisplayObject = (parts[i].match(/^\d+$/) ? (int(parts[i]) >= 0 && int(parts[i]) < cont.numChildren ? cont.getChildAt(int(parts[i])) : null) : FindRecursive(cont, parts[i]));
						if (findchild)
						{
							bounds  = GetFixedRect(findchild);
							rec.graphics.lineStyle(2, 0xFFCC00);rec.graphics.drawRect(bounds.x, bounds.y, bounds.width, bounds.height);
							res += htmlFor(findchild, i, parts.length, base + ':' + GetPathFromStage(findchild));
							cont = findchild as DisplayObjectContainer;
						}
						else res += 'COULD NOT FIND OBJECT WITH NAME [' + parts[i] + ']';
					}
				}
				if (listtype == 20) //dump static stuff from a global class
				{
					var GlobalClass:Class;
					try { GlobalClass = loaderdomain.getDefinition(params[1]) as Class; } catch (e:*) { return 'ERR[' + e + ']'; }
					res = dumpobj(GlobalClass).replace(/\n/g,'<br>').replace(/  /g,'&nbsp; ');
				}
				if (listtype == 30) //output all objects below a x,y coordinate
				{
					var pt:Point = new Point(uint(params[1]), uint(params[2]));
					cont = o as DisplayObjectContainer;
					try { res += FindObjectAt(cont, pt, params[0]); } catch (e:*) { res += 'FINDERR[' + e + '][' + e.getStackTrace() + ']'; }
				}
				return res;
			}

			private function dumpobj(obj:*, recurse:int = 0, seen:Array = null, printed:Array = null, attrname:String = null):String
			{
				if (obj is int || obj is Boolean || obj is Number || obj is uint || obj == null) return String(obj);
				if (obj is String) { var str:String = (obj as String); return (!str ? '' : (str.match(/^[\x01-\x7F]+$/) ? str : ' ... BINARYSTRING (' + str.length + ' bytes) ...')); }
				if (obj is ByteArray) { return '[BYTEARRAY ' + (obj as ByteArray).length + '] ...'; }
				var classname:String = getQualifiedClassName(obj);
				if (classname.indexOf('flash.geom') == 0) return '[' + classname + '] ' + obj;

				if (seen == null) seen = new Array();
				var seenidx:int = seen.indexOf(obj);
				var res:String = '[' + (seenidx >= 0 ? seenidx : seen.push(obj)-1) + '#', indent:String = StringUtil.repeat('  ', recurse);
				if (recurse > 2) return res + (obj is Array ? 'ARRAY ' + arr.length + ']' : 'OBJECT ' + classname + ']') + ' (too deep recursion)';
				if (obj is Array)
				{
					var arr:Array = obj as Array;
					if (!arr.length) return '[ARRAY EMPTY]';
					res += '[ARRAY ' + arr.length + ']\n' + indent + '{\n';
					for (var i:int = 0; i < arr.length; i++) res += indent + '  ' + '[i] = ' + dumpobj(arr[i], recurse + 1, seen, printed) + '\n';
				}
				else
				{
					if (attrname == 'parent' || attrname == 'root' || attrname == 'stage' || attrname == 'graphics' || attrname == 'loaderInfo' || attrname == 'soundTransform' || attrname == 'textSnapshot') return '[OBJECT ' + classname + '] (skipped)';
					if (printed == null) printed = new Array();
					if (printed.indexOf(obj) >= 0) return res + 'OBJECT ' + classname + ']' + ' (already printed)';
					printed.push(obj)
					res += 'OBJECT ' + classname + ']\n' + indent + '{\n' + indent + '  [s] ' + obj +'\n';
					var dt:XML = describeType(obj);
					for (var accessors:* = dt..accessor, ia:int = 0; ia < accessors.length(); ia++)
					{ res += indent + '  [a] ' + accessors[ia].@name + ' = '; try { res += dumpobj(obj[accessors[ia].@name], recurse + 1, seen, printed, accessors[ia].@name) + '\n'; } catch (e:*) { res += '???\n'; } }
					for (var variables:* = dt..variable, iv:int = 0; iv < variables.length(); iv++)
					{ res += indent + '  [v] ' + variables[iv].@name + ' = '; try { res += dumpobj(obj[variables[iv].@name], recurse + 1, seen, printed) + '\n'; } catch (e:*) { res += '???\n'; } }
					for (var constants:* = dt..constant, ic:int = 0; ic < constants.length(); ic++)
					{ res += indent + '  [c] ' + constants[ic].@name + ' = '; try { res += dumpobj(obj[constants[ic].@name], recurse + 1, seen, printed) + '\n'; } catch (e:*) { res += '???\n'; } }
					for (var methods:* = dt..method, im:int = 0; im < methods.length(); im++)
					{ res += indent + '  [m] ' + methods[im].@name + '(' + methods[im]..parameter.@type.toXMLString().replace(/\n/g,', ') + ')\n'; }
					var numChildren:int = 0; try { numChildren = obj.numChildren; } catch (e:*) { }
					for (var iC:int = 0; iC < numChildren; iC++)
					{ res += indent + '  [C] '; try { res += obj.getChildAt(iC).name + ' = ' + dumpobj(obj.getChildAt(iC), recurse + 1, seen, printed) + '\n'; } catch (e:*) { res += '???\n'; } }
					for(var t:Object in obj)
					{ res += indent + '  [t] ' + t + ' = '; try { res += dumpobj(obj[t], recurse + 1, seen, printed) + '\n'; } catch (e:*) { res += '???\n'; } }
					try { for (var ii:int = 0; ii < obj.length; ii++)
					{ res += indent + '  [i] [' + ii + '] = '; try { res += dumpobj(obj[ii], recurse + 1, seen, printed) + '\n'; } catch (e:*) { res += '???\n'; } } } catch (e:*) { }
				}
				return res + indent + '}';
			}

			private function GetPathFromStage(o:DisplayObject):String
			{
				var thispath:String;
				var c:DisplayObject = o, p:DisplayObjectContainer = c.parent;
				if (p)
				{
					try { thispath = String(p.getChildIndex(c)); } catch (e:*) { mylog('FIRSTPATHERR[' + e + ']'); }
					try { for (c = p, p = p.parent; p && c != loaderstage; c = p, p = p.parent) { thispath = p.getChildIndex(c) + ':' + thispath; } } catch (e:*) { mylog('PATHERR[' + e + ']'); }
				}
				else { mylog('NOPARENT' + '<textarea>'+describeType(o).toXMLString()+'</textarea>'); }
				return thispath;
			}

			private function FindObjectAt(cont:DisplayObjectContainer, pt:Point, path:String, namepath:String = ''):String
			{
				var res:String = '';
				for (var i:int = 0; i < cont.numChildren; i++)
				{
					var child:DisplayObject = cont.getChildAt(i);
					if (!child.visible) continue;
					var bounds:Rectangle = GetFixedRect(child);
					if (!bounds.containsPoint(pt)) continue;
					rec.graphics.lineStyle(2, 0xFFCC00);
					rec.graphics.drawRect(bounds.x, bounds.y, bounds.width, bounds.height);
					res += (namepath ? namepath + '/' : '') + child.name + ' =&gt; ' + htmlFor(child, i, cont.numChildren, path + ':' + i);

					var childcont:DisplayObjectContainer = child as DisplayObjectContainer;
					if (childcont) res += FindObjectAt(childcont, pt, path + ':' + i, (namepath ? namepath + '/' : '') + child.name);
				}
				return res;
			}

			private function GetFixedRect(obj:DisplayObject):Rectangle
			{
				var bounds:Rectangle = obj.getRect(loaderstage);
				if (!bounds.width && 'hitTestState' in obj)
				{
					bounds = obj['hitTestState'].getRect(loaderstage);
					var pt00:Point = obj.localToGlobal(new Point(0, 0))
					bounds.x += pt00.x;
					bounds.y += pt00.y;
				}
				return bounds;
			}
		}
	}
}
