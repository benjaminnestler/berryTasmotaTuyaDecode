var tuya_decode = module("tuya_decode")

class TuyaDecodeDriver : Driver
  static var printPrefix = "[TYA-DEC]"
  #- This will be the map for all datapoints
    {
      "groups" : {
        "temp" : "Room temperatures"
      },
      "showDatapointsOfGroups" : [
        "temp"
      ],
      "datapoints" : {
        "1" : {                               # required - The number of the datapoint
            "name" : "nameYourDatapoint",     # required - Name which will be shown on the WebUI
            "type" : 1,                       # required - Select the datapoint type
            "defaultValue" : false            # required - what should be the default value after initialisation
            "formatCode" : "%d %%"            # optional - if you want to show the value in a specific format; thats the right place to add an unit to the datapoint.
            "multiply" : "0.1"                # optional - if you want to add a multiplier or divisor to your value
            "enumDesc" : {                    # optional - if you want to add a enum description for datapoints of type 4 (enum)
              "0" : "On",
              "1" : "Off"
            }
            "group" : "temp"                  # optional - if you want to add group definition to your datapoint (the WebUI shows all the groups and you can decide which group you want to show)
        },
        ...                                     # Add further datapoints for decoding
      }
    }
  -#
  var dp                                    # map of all datapoints, exported from datapoints.json
  var orderedList                           # list of orderer datapoints (ascending)
  var webUIGroupSelected                    # list of selected groups to show datapoints of this group, can be dynamically switched
  var webUIGroupNames                       # map of group abbreviation & names, exported from datapoints.json
  var printDebug                            # bool, lets print some debug infos to berry script console if active
  
  def init()
    import json
    import path
    var jsonDPfile

    if path.exists(tasmota.wd .. "datapoints.json")
      jsonDPfile = open(tasmota.wd .. "datapoints.json", 'r')
      print(self.printPrefix, "datapoints.json load from tapp.")
    elif path.exists("datapoints.json")
      jsonDPfile = open("datapoints.json", 'r')
      print(self.printPrefix, "datapoints.json load external.")
    else
      print(self.printPrefix, "datapoints.json not found!")
    end

    if nil != jsonDPfile
      var content = json.load(jsonDPfile.read())
      jsonDPfile.close()
      if isinstance(content, map)
        self.dp = map()
        if content.contains("datapoints")
          self.dp = content["datapoints"]
          var unorderedList = []
          for key:self.dp.keys()
            unorderedList.push(number(key))
          end
          self.orderedList = self.bubbleSort(unorderedList)
          if content.contains("groups")
            self.webUIGroupNames = map()
            self.webUIGroupNames = content["groups"]
          end
          if content.contains("showDatapointsOfGroups")
            if size(content["showDatapointsOfGroups"])
              self.webUIGroupSelected = []
              self.webUIGroupSelected = content["showDatapointsOfGroups"]
            end
          end
          if content.contains("debug")
            self.printDebug = content["debug"] == true ? 1 : 0
          end
          tasmota.add_driver(self)
          tasmota.add_rule("TuyaReceived", /data -> self.TuyaDecode(data))
          print(self.printPrefix, "init done")
        else
          print(self.printPrefix, "failed to find \"datapoints\"-keyword in datapoints.json")
        end
      else
        print(self.printPrefix, "failed to load datapoints.json")
      end
    else
      print(self.printPrefix, "failed to open datapoints.json")
    end
  end

  def deInit()
    self.dp = nil
    self.orderedList = nil
    self.webUIGroupSelected = nil
    self.webUIGroupNames = nil
    self.printDebug = false

    tasmota.remove_driver(self)
    tasmota.remove_rule("TuyaReceived")
    tasmota.gc()
  end

  def areGroupsDefined()
    return size(self.webUIGroupNames) ? true : false
  end

  def bubbleSort(arr)
    var n = size(arr) - 1
    for i: 0 .. (n-1)
      for j: 0 .. (n-i-1)
        if arr[j] > arr[j+1]
          # Swap elements if they are in the wrong order
          var temp = arr[j]
          arr[j] = arr[j+1]
          arr[j+1] = temp
        end
      end
    end
  
    return arr
  end

  def getIdByKey (key)
    import string
    if nil == key || nil == self.dp
      return nil
    end
    
    var keySplit = string.split(key, "DpType")
    #print(size(keySplit), keySplit)
    keySplit = string.split(keySplit[1], "Id")
    #print(size(keySplit), keySplit)
    var dpType = number(keySplit[0])
    #print ("DpType extracted: ", dpType)
    # need the dpId as string to get the object and iterate through keys
    var dpId = string.format("%d", keySplit[1])
    #print ("DpId extracted: ", dpId)
    for rootKey: self.dp.keys()
      #print(rootKey, dpId)
      if dpId == rootKey
        #print("Found:", self.dp[dpId])
        return dpId
      end
    end
  end

  def checkTypeIsReal (dpId)
    import string
    if nil != dpId
      if self.dp[dpId].contains('formatCode')
        return string.find(self.dp[dpId]['formatCode'], "f")
      end
    end

    return nil
  end

  def decodeEnum (dpId, value)
    import string
    if nil != dpId
      if self.dp[dpId].contains('enumDesc')
        var strValue = string.format("%d", value)
        if self.dp[dpId]['enumDesc'].contains(strValue)
          return self.dp[dpId]['enumDesc'][strValue]
        end
      end
    end

    return nil
  end

  def TuyaDecode(data)
    import string
    
    #print("Tuya raw data: ", data)

    if data['Cmnd'] == 7 && data['CmndData'] != nil
      for key:data.keys()
        if 0 == string.find(key, "DpType")
          #print("found key: ", key)
          var dpId = self.getIdByKey(key)
          if dpId != nil
            var dpType = self.dp[dpId]['type']
            var rawValue = data[key]
            var formatCode = "%s"
            var formatedValue = ""

            if 0 == dpType        # raw
              self.dp[dpId]['valueRaw'] = data[dpId]['DpIdData']
              formatedValue = data[dpId]['DpIdData']
            elif 1 == dpType      # boolean
              formatedValue = bool(rawValue) ? "true" : "false"
            elif 2 == dpType      # value
              var multiply = self.dp[dpId].contains('multiply') ? self.dp[dpId]['multiply'] : 1
              formatCode = self.dp[dpId].contains('formatCode') ? self.dp[dpId]['formatCode'] : "%d"
              formatedValue = (self.checkTypeIsReal(dpId) ? real(rawValue) : number(rawValue)) * multiply
            elif 3 == dpType      # string
              formatedValue = rawValue
            elif 4 == dpType      # enum
              var enumValue = self.decodeEnum(dpId, rawValue)
              formatCode = enumValue ? "%s" : "%d"
              formatedValue = enumValue ? enumValue : number(rawValue)
            elif 5 == dpType      # fault
              formatedValue = data[dpId]['DpIdData']
            end

            self.dp[dpId]['valueRaw'] = rawValue
            self.dp[dpId]['valueFormatedAsString'] = string.format(formatCode, formatedValue)

            if (self.printDebug)
              print(self.printPrefix, "DpID[", dpId,"] = ", self.dp[dpId]['valueRaw'], " --> ", self.dp[dpId]['name'], "= ", self.dp[dpId]['valueFormatedAsString'])
            end
          else
            if (self.printDebug)
              var idStrSplit = string.split(key, "Id")
              var id = idStrSplit[1]
              print(self.printPrefix, "DpID[", id, "] Decoding not possible due to missing description. Add a datapoints object in the datapoints.json file to decode this DpID.")
            end
          end
          break
        end
      end
    end
  end

  #######################################################################
  # Called by tasmota and refreshes values on Main page 
  #######################################################################
  def web_sensor()
    var showValues = true
    var minOneSelectedGroup = false
    if self.areGroupsDefined()
      minOneSelectedGroup = size(self.webUIGroupSelected) ? true : false
      showValues = minOneSelectedGroup ? true : false
    end

    if !showValues
      return
    end

    import string
    var msg = ""
    var msgJSON = map()   

    #- step 1, get the short group names and add the group as object to msgJSON
    or create a 'default' -#
    if minOneSelectedGroup
      for header: self.webUIGroupSelected
        msgJSON[header] = {}
      end
    else
      msgJSON['default'] = {}
    end

    # step 2, get the datapoints and add the data to show for the datapoints (to group objects)
    for key: self.dp.keys()
      var group = 'default'
      if minOneSelectedGroup
        group = self.dp[key].contains('group') ? self.dp[key]['group'] : nil
      end
      
      if group && msgJSON.contains(group)
        var name = self.dp[key].contains('name') ? self.dp[key]['name'] : "undefined"
        var value = self.dp[key].contains('valueFormatedAsString') ? self.dp[key]['valueFormatedAsString'] : (self.dp[key].contains('defaultValue') ? self.dp[key]['defaultValue'] : "")
        var datapointString = string.format("{s}(DP%s) %s {m}%s {e}",
          key, name, value 
        )
        var dpId = string.format("%d", key)
        
        msgJSON[group][dpId] = datapointString
      end
    end

    # step 3, fill the msg-array
    for header: msgJSON.keys()
      if (minOneSelectedGroup)
        var headline = self.webUIGroupNames.contains(header) ? self.webUIGroupNames[header] : header
        msg += string.format("{s}%s{e}", headline)
      end
      
      for idx: self.orderedList.keys()
        var idxStr = string.format("%d", self.orderedList[idx])
        if msgJSON[header].contains(idxStr)
          msg += msgJSON[header][idxStr]
        end
      end
    end

    # send the prepared message to WebUI
    tasmota.web_send_decimal(msg)
  end

  #######################################################################
  # Add button to the Main page
  #######################################################################
  def web_add_main_button()
    if self.areGroupsDefined()
      import webserver
      webserver.content_send(
        "<form id=but_tuya_decode_ui_cfg style='display: block;' action='tuya_decode_ui_config' method='get'><button>Tuya decode UI config</button></form><p></p>")
    end
  end

  def getRawTitleWithoutHTML (title)
    import string
    var parsed = false
    var extracted = ""
    var searchString = title
    while parsed == false 
      var splitString = string.split(searchString, ">", 1)
      #print ("split ", splitString)
      if size(splitString) == 2
        var firstByte = string.byte(splitString[1])
        var firstByteString = string.format("%c",firstByte)
        #print ("firstByte ", firstByteString)
        if firstByteString != "<"
          var splitString2 = string.split(splitString[1], "<", 1)
          extracted = splitString2[0]
          parsed = true
        else
          searchString = splitString[1]
        end
      end
    end
    return extracted
  end

  #######################################################################
  # Show main config
  #######################################################################
  def show_main_config()
    import webserver
  
    # Reload JSON file
    webserver.content_send("<fieldset><legend><b>&nbsp;Tuya decode reload JSON &nbsp;</b></legend>"
                          "<p style='width:320px;'>Reinit a new uploaded datapoints.json file.</p>"
                          "<form action='/tuya_decode_ui_config' method='post'"
                          "onsubmit='return confirm(\"ReInit datapoints.json?\");'>")
    webserver.content_send("<p></p><button name='reinit' class='button bgrn'>ReInit</button></form></p>"
                           "</fieldset><p></p>")

    if self.areGroupsDefined()
      # Group selection
      webserver.content_send("<fieldset><legend><b>&nbsp;Tuya decode UI config &nbsp;</b></legend>"
                            "<p style='width:320px;'>Select the groups of datapoints you want to show on the main Tasmota page.</p>"
                            "<form action='/tuya_decode_ui_config' method='post'>")
    
      # create labels and checkbox for group config
      for groupAbbreviation: self.webUIGroupNames.keys()
        var checked = ""
        for groupSelected: self.webUIGroupSelected.keys()
          if self.webUIGroupSelected[groupSelected] == groupAbbreviation
            checked = "checked"
            break
          end
        end

        webserver.content_send(f"<p><input id='ui_cfg_{groupAbbreviation}' type='checkbox' name='ui_cfg_{groupAbbreviation}' {checked}>")
        webserver.content_send(f"<label for='ui_cfg_{groupAbbreviation}'>{self.getRawTitleWithoutHTML(self.webUIGroupNames[groupAbbreviation])}</label></p>")
      end

      webserver.content_send("<p></p><button name='save' class='button bgrn'>Save</button></form></p>"
                            "</fieldset><p></p>")
    end
  end

  #- ---------------------------------------------------------------------- -#
  # respond to web_add_handler() event to register web listeners
  #- ---------------------------------------------------------------------- -#
  #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
  def web_add_handler()
    import webserver
    #- we need to register a closure, not just a function, that captures the current instance -#
    webserver.on("/tuya_decode_ui_config", / -> self.page_view(), webserver.HTTP_GET)
    webserver.on("/tuya_decode_ui_config", / -> self.page_ctl(), webserver.HTTP_POST)
  end

  #######################################################################
  # Display the complete page
  #######################################################################
  def page_view()
    import webserver
    if !webserver.check_privileged_access() return nil end

    webserver.content_start("Tuya decode UI config")  #- title of the web page -#
    webserver.content_send_style()                    #- send standard Tasmota styles -#

    self.show_main_config()

    webserver.content_button(webserver.BUTTON_MAIN)   #- back to main -#

    webserver.content_stop()                          #- end of web page -#
  end

  #######################################################################
  # Web Controller, called by POST to '/tuya_decode_ui_config'
  #######################################################################
  def page_ctl()
    import webserver
    import string
    if !webserver.check_privileged_access() return nil end

    try
      if webserver.has_arg("save")
        self.webUIGroupSelected.clear()
        for groupAbbreviation: self.webUIGroupNames.keys()
          var ui_cfg_string = string.format("ui_cfg_%s", groupAbbreviation)
          if webserver.has_arg(ui_cfg_string)
            self.webUIGroupSelected.push(groupAbbreviation)
          end
        end
        
        # Back to Main
        webserver.redirect("/?")
      elif webserver.has_arg("reinit")
        self.deInit()
        self.init()
        tasmota.cmd("TuyaSend0")

        # Back to Main
        webserver.redirect("/?")
      else
        raise "value_error", "Unknown command"
      end
    except .. as err, msg
      print(format("BRY: Exception> '%s' - %s", err, msg))
      # display error page
      webserver.content_start("Tuya decode UI config error")  # title of the web page
      webserver.content_send_style()                          # send standard Tasmota styles

      webserver.content_send(format("<p style='width:340px;'><b>Exception:</b><br>'%s'<br>%s</p>", err, msg))

      webserver.content_button(webserver.BUTTON_MAIN)         # button back to management page
      webserver.content_stop()                                # end of web page
    end

  end

end

tuya_decode.TuyaDecodeDriver = TuyaDecodeDriver

#- create and register driver in Tasmota -#
if tasmota
  var ui = tuya_decode.TuyaDecodeDriver()
  
  # Activate following statement, if using the embedded berry console 
  # Deactivate in autoexec.be (tasmota calls the function after restart)
  # ui.web_add_handler()
end

return tuya_decode

# Activate following statement, if using the embedded berry console 
# Deactivate in autoexec.be
# import tuya_decode
