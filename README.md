# Overview

This repo represents the implementation of a Tuya datapoint decoder. The decoded datapoints will be shown on the Main WebUI of Tasmota.

![example_webUI](/assets/example_webUI.png)

### Configure your datapoints
The device configuration can be done in a JSON file which is named as `datapoints.json`.

The JSON file has the following structure:

```json
{
    "debug" : true,
    "groups" : {
        "tempC" : "<p><b><u>Room temperature value</u></b></p>",
    },
    "showDatapointsOfGroups" : [
        "tempC"
    ],
    "datapoints" : {
        "24" : {
            "name" : "Current temperature",
            "type" : 2,
            "defaultValue" : "0",
            "multiply" : 0.1,
            "formatCode" : "%.1f °C",
            "group" : "tempC"
        },
        "23" : {
            "name" : "Temperature Scale (°C/°F)",
            "type" : 4,
            "defaultValue" : "0", 
            "enumDesc" : {
                "0" : "°C",
                "1" : "°F"
            },
            "group" : "config_temp"
        }
    }
}
```
The `debug` key holds a boolean value. If `true` the berry script pushes some decoding printf's to berry scripting console.

The `groups`-object lets you create groups to sort your datapoints. You can use HTML code to use some style features. Define a abbreviation as key and a short description (a good length is around 20 characters, the WebUI will be resized if you use more characters) which will be shown as title for your datapoints.

Write your defined abbreviations of `groups`-object to the `showDatapointsOfGroups`-array to control the display state of the grouped datapoints.

Previously described elements (`debug`, `groups` and `showDatapointsOfGroups`) are optional elements.

In the `datapoints`-object you have to describe all the datapoints you want to decode. As shown in the above snippet, there are some required and some optional keys to fill

- `name` : _required_, A short description of the datapoint (will be shown on WebUI)
- `type` : _required_, the type of the datapint (see Tuya or Tasmota documentation for datatype descriptions)
- `defaultValue` : _required_, The script uses this value to load a default vale for this datapoint. This value will be shown until the TuyaMCU sends (or responses) a refreshed value
- `group` : _optional_, use the one of the abbreviations defined in `groups`-object to add this datapoint to a group

For following types are some optional keys possible:
__type = 4 (enum):__
- `enumDesc`: _optional_, object, describe the enum values as key-value pairs (see datapoint 23 in the JSON snippet above)

__type = 2 (value):__
- `multiply`: _optional_, add a multiplier to the raw-data value. This multiplier is only used to display the value
- `formatCode`: _optional_, add a format-code to format your datapoint before displaying. This is the right point to add an unit. You can use the berry format codes of `string.format()` function. See the berry-documentation for more information.

### Let's go
If you described your datapoints in a `datapoints.json` file you can upload the prepared tapp file `tuya_decode.tapp` (in the folder `tapp`). Upload your `datapoints.json` and restart Tasmota (e.g. via WebUI).

Your decoder should work and decode the described tuya datapoints. If there are exceptions or errors the berry console prints some information. Feel free to create Issues in this repository.

If you added some groups of datapoints you can dynamically select which groups should be shown. Click on the ___Tuya decode UI config___ button to __change the selection__ or to __reinit a new loaded datapoints.json__ file.

### Being in the sourcecode
#### Write some berry code
if you want to add further features or bugfixes :-).

#### Pack the berry code with necessary source files in a Tasmota app

Simply call `tappExcJSON.bash` or `tappIncJSON.bash` file. Maybe you have to change the execution rights after download. 
```
chmod +x <the_tapp_script>.bash
```
If you add or remove sources, edit the bash-script files.

If you change your sourcecode and want to refresh the tapp file, execute one of the bash-scripts. 
- Use `tappExcJSON.bash` to create a Tasmota app without an integrated datapoints.json file. You have to load a `datapoints.json` file via Tasmota WebUI _Manage File sytem_ -> Upload File dialog. 
- Use `tappIncJSON.bash` to create a Tasmota app including the `datapoints.json` file of src-directory.

#### Upload via WebUI File Uploader page

Upload the *.tapp-file to your device and enjoy the decoded Tuya data points on your WebUI.
