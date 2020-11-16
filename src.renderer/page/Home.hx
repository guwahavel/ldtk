package page;

import hxd.Key;

class Home extends Page {
	public static var ME : Home;

	public function new() {
		super();

		ME = this;
		loadPageTemplate("home", {
			app: Const.APP_NAME,
			appVer: Const.getAppVersion(),
			deepnightUrl: Const.DEEPNIGHT_URL,
			jsonDocUrl: Const.JSON_DOC_URL,
			docUrl: Const.DOCUMENTATION_URL,
			websiteUrl : Const.WEBSITE_URL,
			issueUrl : Const.ISSUES_URL,
			appChangelog: StringTools.htmlEscape( Const.APP_CHANGELOG_MD),
			jsonChangelog: StringTools.htmlEscape( Const.JSON_CHANGELOG_MD ),
			jsonFormat: StringTools.htmlEscape( Const.JSON_FORMAT_MD ),
		});
		App.ME.setWindowTitle();

		jPage.find(".changelogs code").each( function(idx,e) {
			var jCode = new J(e);
			if( (~/sample/i).match( jCode.text().toLowerCase() ) ) {
				var jLink = new J('<a href="#" class="discreet">${jCode.text()}</a>');
				jLink.click( function(ev:js.jquery.Event) {
					ev.preventDefault();
					onLoadSamples();
				});
				jCode.replaceWith(jLink);
			}
		});

		// Buttons
		jPage.find(".load").click( function(ev) {
			onLoad();
		});

		jPage.find(".samples").click( function(ev) {
			onLoadSamples();
		});

		jPage.find(".new").click( function(ev) {
			onNew();
		});

		jPage.find(".buy").click( (ev)->{
			var w = new ui.Modal();
			w.loadTemplate("buy", {
				app: Const.APP_NAME,
				itchUrl: Const.ITCH_IO_BUY_URL,
				gitHubSponsorUrl: Const.GITHUB_SPONSOR_URL,
			});
			w.jContent.find("[data-link]").click((ev:js.jquery.Event)->{
				var jButton = ev.getThis();
				var url = jButton.attr("data-link");
				electron.Shell.openExternal(url);
			});
		});

		var jFullscreenBt = jPage.find("button.fullscreen");
		var jChangelogs = jPage.find(".changelogsWrapper");

		jFullscreenBt.click( function(ev) {
			jChangelogs.toggleClass("fullscreen");
			var btIcon = jFullscreenBt.find(".icon");
			btIcon.removeClass();
			if( jChangelogs.hasClass("fullscreen") )
				btIcon.addClass("icon fullscreen_exit");
			else
				btIcon.addClass("icon fullscreen");
		});

		// jPage.find(".exit").click( function(ev) {
		// 	App.ME.exit(true);
		// });

		updateRecents();
	}

	function updateRecents() {
		ui.Tip.clear();

		var jRecentList = jPage.find("ul.recents");
		jRecentList.empty();

		var recents = App.ME.settings.recentProjects.copy();

		// Automatically detects crash backups
		var i = 0;
		while( i<recents.length ) {
			var fp = dn.FilePath.fromFile(recents[i]);
			var crash = fp.clone();
			crash.fileName+=Const.CRASH_NAME_SUFFIX;
			if( !App.ME.recentProjectsContains(crash.full) && JsTools.fileExists(crash.full) ) {
				recents.insert(i+1, crash.full);
				// i++;
			}
			i++;
		}



		// Trim common path parts
		var trimmedPaths = recents.copy();

		// List drive letters
		var driveLetters = new Map();
		for(path in trimmedPaths ) {
			var d = dn.FilePath.fromFile(path).getDriveLetter();
			driveLetters.set(d,d);
		}

		// Trim paths beginnings, grouped by drive
		var splitPaths = trimmedPaths.map( function(p) return dn.FilePath.fromFile(p).getDirectoryAndFileArray() );
		for(d in driveLetters) {
			// List path indexes in original array
			var sameDriveIndexes = [];
			for(i in 0...trimmedPaths.length)
				if( dn.FilePath.fromFile( trimmedPaths[i] ).getDriveLetter() == d )
					sameDriveIndexes.push(i);

			// Trim while beginning is the same
			var trimMore = true;
			var trim = 0;
			while( trimMore ) {
				var firstIdx = sameDriveIndexes[0];
				for( idx in sameDriveIndexes )
					if( trim>=splitPaths[idx].length-2 || splitPaths[idx][trim] != splitPaths[firstIdx][trim] ) {
						trimMore = false;
						break;
					}
				if( trimMore )
					trim++;
			}

			// Apply trimming to array
			while( trim>0 ) {
				for( idx in sameDriveIndexes )
					splitPaths[idx].shift();
				trim--;
			}
		}
		trimmedPaths = splitPaths.map( arr->arr.join("/") );



		// List files
		var i = recents.length-1;
		while( i>=0 ) {
			var p = recents[i];
			var isCrashFile = p.indexOf( Const.CRASH_NAME_SUFFIX )>=0;
			var li = new J('<li/>');
			li.appendTo(jRecentList);


			if( !App.ME.isSample(p,true) ) {
				var col = C.toBlack( C.fromStringLight( dn.FilePath.fromDir(trimmedPaths[i]).getDirectoryArray()[0] ), 0.3 );
				li.append( JsTools.makePath(trimmedPaths[i], col, true) );
			}
			else {
				// Sample file
				li.addClass("sample");
				var jPath = new J('<div class="path"/>');
				jPath.append('<span class="highlight">${Const.APP_NAME} sample</span>');
				jPath.append('<span>${dn.FilePath.extractFileWithExt(p)}</span>');
				jPath.appendTo(li);
			}

			li.click( function(ev) {
				if( !App.ME.loadProject(p) )
					updateRecents();
			});

			if( !JsTools.fileExists(p) )
				li.addClass("missing");

			if( isCrashFile )
				li.addClass("crash");

			ui.modal.ContextMenu.addTo(li, [
				{
					label: L.t._("Locate file"),
					cond: null,
					cb: JsTools.exploreToFile.bind(p, true),
				},
				{
					label: L.t._("Remove from history"),
					cond: ()->!isCrashFile,
					cb: ()->{
						App.ME.unregisterRecentProject(p);
						updateRecents();
					}
				},
				{
					label: L.t._("Delete this crash backup file"),
					cond: ()->isCrashFile,
					cb: ()->{
						JsTools.removeFile(p);
						App.ME.unregisterRecentProject(p);
						updateRecents();
					}
				},
				{
					label: L.t._("Clear all history"),
					cond: null,
					cb: ()->{
						App.ME.clearRecentProjects();
						updateRecents();
					}
				},
			]);
			i--;
		}

		JsTools.parseComponents(jRecentList);
	}


	public function onLoad() {
		dn.electron.Dialogs.open(["."+Const.FILE_EXTENSION,".json"], App.ME.getDefaultDialogDir(), function(filePath) {
			if( !App.ME.loadProject(filePath) )
				updateRecents();
		});
	}

	public function onLoadSamples() {
		dn.electron.Dialogs.open(["."+Const.FILE_EXTENSION], JsTools.getSamplesDir(), function(filePath) {
			App.ME.loadProject(filePath);
		});
	}

	public function onNew() {
		dn.electron.Dialogs.saveAs(["."+Const.FILE_EXTENSION], App.ME.getDefaultDialogDir(), function(filePath) {
			var fp = dn.FilePath.fromFile(filePath);
			fp.extension = "ldtk";

			var p = data.Project.createEmpty();
			var data = JsTools.prepareProjectFile(p);
			JsTools.writeFileBytes(fp.full, data.bytes);

			N.msg("New project created: "+fp.full);
			App.ME.loadPage( ()->new Editor(p, fp.full) );
		});
	}


	override function onKeyPress(keyCode:Int) {
		super.onKeyPress(keyCode);

		switch keyCode {
			case K.W, K.Q:
				if( App.ME.isCtrlDown() )
					App.ME.exit();

			case K.ENTER:
				jPage.find("ul.recents li:first").click();

			case K.ESCAPE:
				if( jPage.find(".changelogsWrapper").hasClass("fullscreen") )
					jPage.find("button.fullscreen").click();
		}
	}

}
