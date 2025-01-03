# XRT SMI Configuration

This `xrt_smi_config.json` file is a configuration file used to define subcommands and their options for the Xilinx Runtime (XRT) System Management Interface (SMI) tool. This JSON file specifies the available subcommands, their descriptions, tags, and the options associated with each subcommand.

## Structure

The JSON file is structured as follows:
- **subcommands**: An array of subcommand objects. Each subcommand object contains details about a specific subcommand, including its name, description, tag, and options.

## Fields

### Subcommand Object

Each subcommand object contains the following fields:
- **name**: The name of the subcommand.
  - Type: `string`
  - Example: `"validate"`
- **description**: A brief description of what the subcommand does.
  - Type: `string`
  - Example: `"Validates the given device by executing the platform's validate executable."`
- **tag**: A tag categorizing the subcommand.
  - Type: `string`
  - Example: `"basic"`
- **options**: An array of option objects. Each option object defines a specific option for the subcommand.

### Option Object

Each option object contains the following fields:
- **name**: The name of the option.
  - Type: `string`
  - Example: `"device"`
- **alias**: A short alias for the option.
  - Type: `string`
  - Example: `"d"`
- **description**: A brief description of what the option does.
  - Type: `string`
  - Example: `"The Bus:Device.Function (e.g., 0000:d8:00.0) device of interest"`
- **tag**: A tag categorizing the option.
  - Type: `string`
  - Example: `"basic"`
- **default_value**: The default value for the option.
  - Type: `string`
  - Example: `""`
- **option_type**: The type of the option, indicating its scope or usage.
  - Type: `string`
  - Example: `"common"`
- **value_type**: The data type of the option's value.
  - Type: `string`
  - Example: `"string"`

## Example

Here is an example of a subcommand object with its options:

```json
{
  "subcommands": [
    {
      "name": "validate",
      "description": "Validates the given device by executing the platform's validate executable.",
      "tag": "basic",
      "options": [
        {
          "name": "device",
          "alias": "d",
          "description": "The Bus:Device.Function (e.g., 0000:d8:00.0) device of interest",
          "tag": "basic",
          "default_value": "",
          "option_type": "common",
          "value_type": "string"
        },
        {
          "name": "format",
          "alias": "f",
          "description": "Report output format",
          "tag": "basic",
          "default_value": "JSON",
          "option_type": "common",
          "value_type": "string"
        },
        {
          "name": "output",
          "alias": "o",
          "description": "Direct the output to the given file",
          "tag": "basic",
          "default_value": "",
          "option_type": "common",
          "value_type": "string"
        }
      ]
    }
  ]
}
