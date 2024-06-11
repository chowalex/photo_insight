--[[----------------------------------------------------------------------------

SinglePhotoDemo.lua
A demo of using GPT-4o to analyze an image and populate an image's title and
other metadata. If available, also uses tagged GPS coordinates of the 
photograph to provide more accurate and detailed information about landmarks.

------------------------------------------------------------------------------]]

-- Access the Lightroom SDK namespaces.
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import "LrStringUtils"
local LrHttp = import 'LrHttp'
local JSON = require "json"
local LrProgressScope = import 'LrProgressScope'
local LrPrefs = import 'LrPrefs'

local DELETE_TEMP_FILES = true
local GPT_MODEL = "gpt-4o"
local MAX_TOKENS = 500

local prefs = LrPrefs.prefsForPlugin()
local openai_api_key = prefs.openai_api_key
local temp_dir = prefs.temp_dir

local EXPORT_SETTINGS = {
  LR_export_destinationType = 'specificFolder',
  LR_export_destinationPathPrefix = temp_dir,
  LR_export_useSubfolder = false,
  LR_format = 'JPEG',
  LR_jpeg_quality = 0.8,
  LR_export_bitDepth = 8,
  LR_renamingTokensOn = false,
  LR_useWatermark = false,
  LR_export_destinationPathSuffix = '',
  LR_collisionHandling = 'overwrite',
  LR_size_doConstrain = true,
  LR_size_maxWidth = 1280,
  LR_size_maxHeight = 1280
}

local function showErrorHandling(func)
  return function(...)
      local status, err = LrTasks.pcall(func, ...)
      if not status then
          myLogger:error("Error occurred: " .. err)
          LrDialogs.message("Error", "An error occurred: " .. err, "critical")
      end
  end
end

local function setTitle(title)
  local catalog = LrApplication.activeCatalog()
  local photo = catalog:getTargetPhoto()

  local success, errorMessage = LrTasks.pcall(function()
    catalog:withWriteAccessDo("Set Photo Title", function(context)
      photo:setRawMetadata("title", title)
    end, {timeout = 3})
  end)
  if not success then
    LrDialogs.message("Error", "Failed to set title: " .. errorMessage, "critical")
  end
end

local function readFile(filePath)
  local file = io.open(filePath, "rb")
  if not file then
      return nil, "Unable to open file " .. filePath
  end

  local content = file:read("*all")
  file:close()
  return content
end

local function describeImage(base64Image, gps)
  local headers = {
		{ field = "Authorization", value = "Bearer " .. openai_api_key },
    { field = "Content-Type", value = "application/json" }
	}

  local locationString = ""
  if gps and gps.latitude and gps.longitude then
    local message = string.format("Latitude: %f, Longitude: %f", gps.latitude, gps.longitude)
    locationString = "The photograph was taken at this location: " .. message .. "; use this information to help identify landmarks or other points of interest."
  end
  
  local body = {
    model = GPT_MODEL,
    messages = {
      {
        role = "system", 
        content = "You are an assistant that generates titles and keywords for photos for the user. Given a photograph, provide a short, succinct title for the provided photograph, identifying any landmarks and points of interest, if applicable. If location coordinates are provided, use the location information to help with identifying potential landmarks. The output should be a JSON object with a 'title' field and a 'keywords' field, which is a list of strings."
      },
      {
            role = "user",
            content = {
                {
                    type = "text",
                    text = "Provide a short succinct title for this image, identifying any landmarks if applicable. " .. locationString
                },
                {
                    type = "image_url",
                    image_url = {
                        url = "data:image/jpeg;base64," .. base64Image
                    }
                }
            }
        }
    },
    max_tokens = MAX_TOKENS
  }
  local jsonBody = JSON:encode(body)
  local result, hdrs = LrHttp.post("https://api.openai.com/v1/chat/completions", jsonBody, headers)  

  if result then
      local response = JSON:decode(result)
      
      if response and response.choices and response.choices[1] and response.choices[1].message and response.choices[1].message.content then
          local content = response.choices[1].message.content
          local jsonContent = content:match("```json(.-)```")
          local parsedContent = JSON:decode(jsonContent)

          if parsedContent and parsedContent.title and parsedContent.keywords then
            setTitle(parsedContent.title)            
          else
            LrDialogs.message("Error", "Failed to decode inner JSON content.", "critical")
            return
          end
      end
  else
      LrDialogs.message("Error", "HTTP request to OpenAI failed", "critical")
      return
  end
end

local function replaceExtension(fileName, newExtension)
  return fileName:match("(.+)%..+$") .. newExtension
end

-- Exports and describes the selected image.
local function exportAndDescribeImage()
  local catalog = LrApplication.activeCatalog()
  local photo = catalog:getTargetPhoto()
  local progressScope = LrProgressScope { title = "Analyzing Image..." }

  if not photo then
      LrDialogs.message("No Photo Selected", "Please select a photo to export and describe.", "info")
      return
  end

  local filename = photo:getFormattedMetadata("fileName")
  if not filename or not LrFileUtils.isWritable(temp_dir) then
    LrDialogs.message("Error", "Cannot access file or directory: " .. temp_dir, "critical")
    return
  end

  local exportedFileName = replaceExtension(filename, ".jpg")
  local gps = photo:getRawMetadata("gps")
  local tempFilePath = LrPathUtils.child(temp_dir, exportedFileName)
  local exportSession = LrExportSession({ photosToExport = { photo }, exportSettings = EXPORT_SETTINGS })

  progressScope:setPortionComplete(0.1, 1)  

  for _, rendition in exportSession:renditions() do
      local success, pathOrMessage = rendition:waitForRender()
      progressScope:setPortionComplete(0.3, 1)

      if success then
          local imageData, err = readFile(tempFilePath)
          if not imageData then
              LrDialogs.message("Error", "Failed to read exported image: " .. err, "critical")
              return
          end

          local base64Image = LrStringUtils.encodeBase64(imageData)
          progressScope:setPortionComplete(0.4, 1)

          describeImage(base64Image, gps)
          progressScope:setPortionComplete(0.9, 1)
          
          if DELETE_TEMP_FILES then
            LrFileUtils.delete(tempFilePath)
          end
      else
          LrDialogs.message("Export Failed", pathOrMessage, "critical")
      end
  end

  progressScope:done()
end

LrTasks.startAsyncTask(exportAndDescribeImage)