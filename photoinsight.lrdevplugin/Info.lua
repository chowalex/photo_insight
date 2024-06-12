--[[----------------------------------------------------------------------------

Info.lua
Summary information for the Photo Insight plug-in.

This plugin analyzes photos using a cloud ML model, and automatically adds
title, caption, keywords to the photo metadata.

------------------------------------------------------------------------------]]

return {
	
	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 1.3,

	LrToolkitIdentifier = 'com.adobe.lightroom.sdk.photoinsight',

	LrPluginName = LOC "$$$/PhotoInsight/PluginName=Photo Insight",
	
	-- Add the menu item under File > Plugin Extras
	
	LrExportMenuItems = {
		title = "Photo Insight",
		file = "AnalyzeSelectedPhotos.lua",
	},

	LrLibraryMenuItems = {
	    {
		    title = LOC "$$$/PhotoInsight/Plugin=Analyze Photos",
		    file = "AnalyzeSelectedPhotos.lua",
		},
	},

  LrPluginInfoProvider = 'PluginInfoProvider.lua',

	VERSION = { major=13, minor=3, revision=0, build="202405092057-40441e28", },
}