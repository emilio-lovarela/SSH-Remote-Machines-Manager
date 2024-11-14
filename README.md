# SSH-Remote-Machines-Manager

This script streamlines the process of connecting to multiple remote machines via SSH using an easily configurable `config.yaml` file. It automates SSH key management, supports ProxyJumps, and includes options for both Ubuntu (Bash) and Windows (WSL) environments.

- **Quick Setup**: Easily configure multiple remote machines in `config.yaml`, specifying details like IP, user, and machine characteristics (e.g., VRAM, CPU).
- **SSH Key Management**: Automatically generate, configure, and copy SSH keys to remote servers for passwordless access.
- **ProxyJump Support**: Seamlessly connect to remote machines via intermediate (proxy) servers.
- **Cross-Platform Compatibility**: Works on Ubuntu with Bash and Windows via WSL, enabling SSH keys to function directly with Windows applications (e.g., VSCode).
- **Remote Command Export**: Exports a function with pre-configured, frequently-used commands for efficient remote machine management.

<div align="center">
<table border="0">
 <tr>
    <td align="center"><b style="font-size:30px">Interface</b></td>
    <td align="center"><b style="font-size:30px">CMD Screenshot</b></td>
 </tr>
 <tr>
    <td align="left">
       
```yaml
Select a machine:
-----------------------
1) Amazon_machine_2
     - VRAM: 24GB
     - CPU: 12 cores
     - RAM: 128GB
2) Machine_dummy
3) My_House_Raspberry
     - VRAM: 64GB
     - OS: Debian
     - ProxyJump: 192.168.1.67 
-----------------------
#?
```

   </td>
   <td>
      <p align="center"> <img src="https://github.com/emilio-lovarela/SSH-Remote-Machines-Manager/blob/main/SSH_Remote_Manager_Example.png?raw=true" alt="screenshot" style="width: 100%; max-width: 600px;"></p>
   </td>
</tr>
</table>
</div> 


## Requirements

Before using this script, you need to install the following dependencies:

- For **Ubuntu** users:
     - **PyYAML**: Required for parsing the YAML configuration file.
     -  **jq**: Used to handle JSON data processing.

     To install these dependencies, run the following commands:

     ```bash
     pip install pyyaml
     sudo apt-get install jq
     ```

- For **Windows** users:
     - **WSL (Windows Subsystem for Linux)**: Required for running the script.
     - Once WSL is installed, make sure to install **PyYAML** and **jq** within the WSL environment.
     
     To install WSL, open a PowerShell terminal as administrator and execute:

     ```powershell
     wsl --install
     ```

     For more details on WSL installation, please refer to the official documentation: [Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install)


## How to Use the Script

1. Clone or download the project files to your local machine.
2. Open the `config.yaml` file and add your remote machines, their IP addresses, usernames, and any other specific characteristics you want to track (such as VRAM, CPU, etc).
3. Run the script to select a machine and establish a connection:

   - For **Ubuntu** users, run:

     ```bash
     ./connect_to_machines.sh
     ```

   - For **Windows** users, execute the following file:

     ```powershell
     script_windows_wsl_users/connect_to_machines.bat
     ```


### Recommendation for Easier Access

If you want to run the script from any location in your operating system, you can add a shortcut to simplify access:

- **On Ubuntu**: Add an alias in your `.bashrc` file by including the following line at the end. This will allow you to run the script using `connect_to_machines` from any terminal:

  ```bash
  alias connect_to_machines='~/<Path_to_file>/connect_to_machines.sh'
  ```
 
  Replace `<Path_to_file>` with the actual path to the script. For example, if the script is in your home directory under `scripts`, the alias would look like:
  ```bash
  alias connect_to_machines='~/scripts/connect_to_machines.sh'
  ```

- **On Windows**: Add the folder `script_windows_wsl_users` to your Windows **PATH**. This will enable you to run the script by typing `connect_to_machines` directly into the Command Prompt or PowerShell. Make sure you execute the `.bat` file for Windows compatibility.

  To add a folder to the Windows PATH, you can follow this tutorial: [How to Edit Your System PATH for Easy Command Line Access](https://www.howtogeek.com/118594/how-to-edit-your-system-path-for-easy-command-line-access/)
 

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
    ProxyJump:
      ip: 192.168.1.67
      user: m.lorial
  Amazon_machine_2:
    ip: 192.168.1.19
    user: maria_garcia
    VRAM: 24GB
    CPU: 12 cores
    RAM: 128GB

options:
  export_commands_to_machine: True  # Export commands function to remote machine
  connect_timeout: 8  # Maximum connection timeout
  use_ssh_key: True  # Use SSH key instead of password
```

### Customizing the Configuration

1. **Add your machines**: Under the `machines` section, add your remote machines by specifying their `ip`, `user`, and any other custom fields such as `VRAM`, `CPU`, `RAM`, etc. These additional fields are optional, but you can use them to document specific characteristics of your machines.

2. **Set up ProxyJump**: If you need to connect to a remote machine via an intermediate jump server, configure `ProxyJump` within the machine entry in `config.yaml`. Add `ProxyJump` with the `user` and `ip` fields for the intermediary machine. This allows seamless SSH connections through the intermediate server, improving access in network-restricted environments.

3. **Adjust options**: You can change the following options under the `options` section:
   - `export_commands_to_machine`: If set to `True`, this will export a function to show a set of useful commands to the remote machine, allowing you to run common used actions like file transfers or process management fastly.
   - `connect_timeout`: This controls the maximum time (in seconds) for the SSH connection attempt.
   - `use_ssh_key`: If set to `True`, the script will try to connect using an SSH key. If no SSH key exists on your local machine, you will be prompted to create one. If set to `False`, the script will ask for a password to connect to the remote machine.

---
