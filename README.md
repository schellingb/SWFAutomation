SWFAutomation
=============

This project offers a method to automate Flash with either JavaScript from inside any browser or from outside of Mozilla Firefox with example programs included written in [C++](C), [Python](Python) and [AutoHotkey](AutoHotkey).  
The script provides methods to read information (text fields and other values), send click events, move elements, change attributes and more.  
It also includes an interactive inspection mode to easily find element names and other information required for automation.

# Installation

Basic operation inside the browser requires two parts.
- You need to install the content debugger version of the Flash Player plugin for your browser.  
  Get it from http://www.adobe.com/support/flashplayer/debug_downloads.html
- Set up the 'mm.cfg' file with the path to the preload swf extension which contains the core JavaScript automation interface.  
  See this [Adobe support page](http://help.adobe.com/en_US/flex/using/WS2db454920e96a9e51e63e3d11c0bf69084-7fc9.html) for the file location for your OS.  
  On Windows, the file is located at `C:\Users\<YOUR_USERNAME>\mm.cfg`.  
  Here's a simple mm.cfg which activates the interactive variant of SWFAutomation:

```ini
SuppressDebuggerExceptionDialogs=1
AllowUserLocalTrust=1
ErrorReportingEnable=0
PolicyFileLog=0
TraceOutputFileEnable=0
PreloadSwf=C:\path\to\SWFAutomation\SWFAutomationPreload_Interactive.swf
```

## Options

At the end of the PreloadSwf setting you can specify a parameter which controls the behavior of SWFAutomation. If for instance the file is specified as `SWFAutomationPreload.swf?object_filter=test` the automation interface will only be made available for embedded objects loaded with a DOM object element ID containing the substring 'test'. Other flash embedded objects will not be acted on.

# Interactive Inspection Mode

Once set up, restart your browser (or at least close and then re-open all tabs containing Flash content) and go to a site with Flash content.  
For example this [basic interactive sample](http://www.adobe.com/devnet/actionscript/samples/interactivity_1.html).

You should see three blue dots at the left side which indicate the interactive preload swf is active. These blue squares can be clicked on to activate the interactive inspector view. When activated, a tree view shows up next to the Flash element with various actions regarding the Flash display objects. The available options are:
- [object CLASSNAME]: Shows the class type of the object and when clicked dumps the object and all parameters/attributes/children/etc.
- [CLICK]: Send a mouse click event to the object
- [VIS]: Toggle visibility of the object
- [FIND]: Find a object by name path, for example 'toggle_btn' or 'beetle/shadow'
- [DUMP]: Dump a global static class, for instance 'flash.external.ExternalInterface'
- [MOUSE]: Indicates an object that can receive mouse events (does not mean it actually handles the events)

In the interactive inspector mode, you can hold the SHIFT key and click the middle mouse button to list up all objects under the mouse cursor. This is the easiest way to find the display object to automate.

For an example of how to use the interactive inspector and how to send a simple click event to a Flash button with JavaScript see [this image](https://raw.githubusercontent.com/schellingb/SWFAutomation/master/README.png).

# Interface

## Name Paths

Interface functions which operate on display objects have a 'path' parameter. The path indicates how to access the element starting from the root object (stage).  
Because in Flash some elements might be dynamically named, paths don't need to be exact. For instance an object with the absolute path 'root3/window/instance33/my_btn' can be referred to as 'window/my_btn'.

## Functions

### inj_click(path:String):Boolean
Send a single left mouse button click event to a display object. Returns true if the event was sent and false if no object exists at the given path.
- `object.inj_click('toggle_btn')`

### inj_mousedownup(path:String):Boolean
Send a left mouse button down event immediately followed by a up event to a display object. Returns true if the events were sent and false if no object exists at the given path. An object might not ever expect the up event to follow so quickly after the down event and thus might behave weird. Other objects might not handle the click event but react to the down/up events.  
- `object.inj_mousedownup('right_btn')`

### inj_get(path:String, ...attribnames):*
Read an attribute of a display object or a sub-object (using multiple attribute names). Return values can be of various simple types (boolean, numeric, strings and simple objects like flash.geom.Point but not complex classes). If the returned value object is too complex a JavaScript exception will be thrown. If no object was found with the path or the attribute doesn't exist, null will be returned.
- `object.inj_get('beetle/shadow', 'scaleY')`
- `object.inj_get('beetle', 'loaderInfo', 'loaderURL')`

### inj_set(path:String, ...attribsvalue):Boolean
Like inj_get described above but one more parameter giving a new value to be set. Returns true if the attribute was set and false if no object exists at the given path or the attribute was not found or not writable.
- `object.inj_set('beetle/shadow', 'scaleX', 1.5)`

### inj_call(path:String, ...attribsparams):*
Call a function of a display object or a sub-object. Multiple parameters can be given before the function name to look up sub-objects and all parameter values after the function name will be passed on. Return values can be of various simple types like inj_get. If no object was found with the path or the function was not found or an exception happened during the call, null will be returned.
- `object.inj_call('beetle', 'toString')`
- `object.inj_call('object', 'subobject', 'function', 'param1', 'param2')`

### inj_move(path:String, x:Number, y:Number):Boolean
Move a display object to the given absolute scene position. Returns true if the object was moved and false if no object exists at the given path.
- `object.inj_move('beetle', 300, 80)`

### inj_static_get(classname:String, ...attribnames):*
Read a static attribute from a class. Behaves identically to inj_get other than the handling of the first parameter.
- `object.inj_static_get('flash.system.System', 'totalMemory')`

### inj_static_set(classname:String, ...attribsvalue):Boolean
Set a static attribute from a class. Behaves identically to inj_set other than the handling of the first parameter.
- `object.inj_static_set('flash.ui.Mouse', 'cursor', 'hand')`

### inj_static_call(classname:String, ...attribsparams):*
Call a static function in a class. Behaves identically to inj_call other than the handling of the first parameter.
- `object.inj_static_call('flash.external.ExternalInterface', 'call', 'eval', '4+3')`

# Requirements

To execute automation controlled from outside Firefox the extension [MozRepl](https://github.com/bard/mozrepl/wiki) needs to be installed and active.

# Building

This repository comes with pre-built .swf files but it also includes a minimal version of the Flex compiler mxmlc (requires Java).
Check Build.bat on how to call mxmlc and how to build the two variants of SWFAutomation.

# License

SWFAutomation is available under the [Unlicense](http://unlicense.org/).
