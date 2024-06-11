local LrColor = import  "LrColor"
local LrHttp = import "LrHttp"
local LrPrefs = import 'LrPrefs'
local LrView = import "LrView"

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

PluginManager = {}

function PluginManager.sectionsForTopOfDialog(viewFactory, properties)
  local f = viewFactory;
  local prefs = LrPrefs.prefsForPlugin();

  if (prefs.temp_dir == nil or prefs.temp_dir == "") then
    prefs.temp_dir = "Z:\\scratch"
  end

   return {
      {
         title = "Cloud API Configuration",
         bind_to_object = prefs,
         f:group_box {
            title = "API Keys",
            fill_horizontal = 1,
            f:row {
               spacing = f:control_spacing(),
               f:static_text {
                  title = "OpenAI",
                  alignment = 'left',
               },
               f:edit_field {
                  immediate = true,
                  value_to_string = true,
                  alignment = 'left',
                  fill_horizontal = 1,
                  width_in_digits = 44,
                  tooltip = "OpenAI API Key",
                  value = LrView.bind('openai_api_key'),
               },
               f:push_button {
                  width = 155,
                  title = "Dashboard",
                  enabled = true,
                  action = function()
                     LrHttp.openUrlInBrowser("https://platform.openai.com")
                  end,
               },
            },
         },
         f:group_box {
          title = "Setup",
          fill_horizontal = 1,
          f:row {
             spacing = f:control_spacing(),
             f:static_text {
                title = "Scratch directory",
                alignment = 'left',
             },
             f:edit_field {
                immediate = true,
                value_to_string = true,
                alignment = 'left',
                fill_horizontal = 1,
                width_in_digits = 50,
                tooltip = "Specify an existing temporary directory",
                value = LrView.bind('temp_dir'),
             },             
          },
       },
      }
   }
end

function PluginManager.sectionsForBottomOfDialog(viewFactory, properties)
   local f = LrView.osFactory();
   return {
      {
         title = "License",
         bind_to_object = prefs,
         f:row {
            spacing = f:control_spacing(),
            f:static_text {
               title = "MIT License",
               width_in_chars = 50,
               height_in_lines = -1,
               fill_horizontal = 1,
               fill_vertical = 1,
            },
         },
      }
   }
end

local function endDialog(properties)
   local prefs = LrPrefs.prefsForPlugin()
   prefs.openai_api_key = trim(properties.openai_api_key)
   prefs.openai_api_key = properties.temp_dir
end

return {
   sectionsForTopOfDialog = sectionsForTopOfDialog,
   sectionsForBottomOfDialog = sectionsForBottomOfDialog,
   endDialog = endDialog
}