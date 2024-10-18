# SSH-Remote-Machines-Manager

This script helps users connect to remote machines via SSH using an easy-to-configure setup file `config.yaml`. It supports using SSH keys and showing machine-specific characteristics. When you run the script, you will be presented with a list of machines from the `config.yaml` file. Each machine can include specific characteristics (such as `VRAM`, `CPU`, etc). You will need to select the machine by entering its corresponding number.

Example:

```bash
Select a machine:
-----------------------
1) Machine_dummy
2) My_House_Raspberry
     - VRAM: 64GB
     - OS: Debian
3) Amazon_machine_2
     - VRAM: 24GB
     - CPU: 12 cores
     - RAM: 128GB
-----------------------
#?
```


## Requirements

Before using this script, you need to install the following dependencies:

- **PyYAML**: Required for parsing the YAML configuration file.
- **jq**: Used to handle JSON data processing.

To install these dependencies, run the following commands:

```bash
pip install pyyaml
sudo apt-get install jq
```

## How to Use the Script

1. Clone or download the project files to your local machine.
2. Open the `config.yaml` file and add your remote machines, their IP addresses, usernames, and any other specific characteristics you want to track (such as VRAM, CPU, etc).
3. Run the script `connect_to_machine.sh` from your terminal to select a machine and establish a connection.

```bash
./connect_to_machine.sh
```

## Default Configuration Example - `config.yaml`

Here’s the default configuration file. You will need to modify this file to match your machines and their details:

```yaml
machines:
  Machine_dummy:
    ip: 192.168.1.20
    user: user2
  My_House_Raspberry:
    ip: 192.168.1.18
    user: alvaro_cride
    VRAM: 64GB
    OS: Debian
  Amazon_machine_2:
    ip: 192.168.1.19
    user: maria_garcia
    VRAM: 24GB
    CPU: 12 cores
    RAM: 128GB
  Machine_dummy_2:
    user:
    GPU: NVIDIA RTX 3060

options:
  export_commands_to_machine: True  # Export commands function to remote machine
  connect_timeout: 8  # Maximum connection timeout
  use_ssh_key: True  # Use SSH key instead of password
```

### Customizing the Configuration

1. **Add your machines**: Under the `machines` section, add your remote machines by specifying their `ip`, `user`, and any other custom fields such as `VRAM`, `CPU`, `RAM`, etc. These additional fields are optional, but you can use them to document specific characteristics of your machines.

2. **Adjust options**: You can change the following options under the `options` section:
   - `export_commands_to_machine`: If set to `True`, this will export a function to show a set of useful commands to the remote machine, allowing you to run common used actions like file transfers or process management fastly.
   - `connect_timeout`: This controls the maximum time (in seconds) for the SSH connection attempt.
   - `use_ssh_key`: If set to `True`, the script will try to connect using an SSH key. If no SSH key exists on your local machine, you will be prompted to create one. If set to `False`, the script will ask for a password to connect to the remote machine.

---
