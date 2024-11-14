#!/bin/bash
# Requires installing pyyaml and jq. Use 'pip install pyyaml' and 'sudo apt-get install jq'

# Define ANSI colors
COLOR_GREEN="\033[1;32m"  # Bright green for machine names
COLOR_RED="\033[1;31m"    # Bright red for dashes
COLOR_CYAN="\033[1;36m"   # Bright cyan
COLOR_RESET="\033[0m"     # Reset color

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}: ${COLOR_GREEN}jq${COLOR_RESET} is not installed."
    echo -e "Please install it by running: ${COLOR_CYAN}sudo apt-get install jq${COLOR_RESET}"
    jq_installed=false
else
    jq_installed=true
fi

# Check if pyyaml is installed
if ! python3 -c "import yaml" &> /dev/null; then
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}: ${COLOR_GREEN}pyyaml${COLOR_RESET} is not installed."
    echo -e "Please install it by running: ${COLOR_CYAN}pip install pyyaml${COLOR_RESET}"
    pyyaml_installed=false
else
    pyyaml_installed=true
fi

# Exit if either dependency is missing
if [[ "$jq_installed" == false || "$pyyaml_installed" == false ]]; then
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}: Required dependencies are missing. Please install them and rerun the script."
    echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to exit."
    read
    exit 1
fi



# Path to the configuration file
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$DIR/config.yaml"

# Check if the configuration file exists
if [[ ! -f $CONFIG_FILE ]]; then
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}"
    echo -e "The ${COLOR_CYAN}$CONFIG_FILE${COLOR_RESET} file does not exist. Please check its location"
    echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
    read
    exit 1
fi

# Load all the configuration at once using Python and store it in a Bash variable
config_data=$(python3 -c "
import yaml, json
with open('$CONFIG_FILE', 'r') as f:
    config = yaml.safe_load(f)
print(json.dumps(config))
")

# Use jq to extract different parts of the config.yaml file
export_commands_to_machine=$(echo "$config_data" | jq -r '.options.export_commands_to_machine')
connect_timeout=$(echo "$config_data" | jq -r '.options.connect_timeout')
use_ssh_key=$(echo "$config_data" | jq -r '.options.use_ssh_key')

# Extract machines
machines=($(echo "$config_data" | jq -r '.machines | keys[]'))

# Check if there are machines in the file
if [[ ${#machines[@]} -eq 0 ]]; then
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}"
    echo -e "No ${COLOR_CYAN}machines${COLOR_RESET} were found in the configuration file."
    echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
    read
    exit 1
fi

# Show the list of machines to select from
echo "Select a machine:"
echo "-----------------------"
declare -A options
i=1
for machine in "${machines[@]}"; do
    # Display the machine name in color
    echo -e "$i) ${COLOR_GREEN}$machine${COLOR_RESET}"

    # Extract and display the characteristics of each machine (excluding ip and user)
    characteristics=$(echo "$config_data" | jq -r ".machines[\"$machine\"] | to_entries | map(select(.key != \"ip\" and .key != \"user\" and .key != \"ProxyJump\"))")
    ProxyJump=$(echo "$config_data" | jq -r ".machines[\"$machine\"].ProxyJump // empty")

    # Print characteristics with red dashes and the desired indentation
    if [[ -n "$characteristics" ]]; then
        echo "$characteristics" | jq -r '.[] | "\(.key):\(.value)"' | while IFS=: read -r key value; do
            echo -e "     ${COLOR_RED}- ${COLOR_RESET}$key: ${COLOR_CYAN}$value${COLOR_RESET}"
        done
    fi

    # Print 'ProxyJump' and the intermediate IP if active
    if [[ -n "$ProxyJump" ]]; then
        pf_ip=$(echo "$config_data" | jq -r ".machines[\"$machine\"].ProxyJump.ip")
        echo -e "     ${COLOR_RED}- ${COLOR_RESET}${COLOR_BLUE}ProxyJump:${COLOR_RESET} ${COLOR_CYAN}$pf_ip${COLOR_RESET}"
    fi

    options[$i]=$machine
    ((i++))
done

# Machine selection process
echo "-----------------------"
while true; do
    read -p "#? " selection
    if [[ $selection =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -lt $i ]]; then
        machine=${options[$selection]}
        break
    else
        echo -e "Please, ${COLOR_CYAN}enter a valid number${COLOR_RESET} between ${COLOR_CYAN}1${COLOR_RESET} and ${COLOR_CYAN}$((i-1))${COLOR_RESET}"
    fi
done

# Get the IP and user of the selected machine
ip=$(echo "$config_data" | jq -r ".machines[\"$machine\"] | select(.ip and .ip != \"\") | .ip")
user=$(echo "$config_data" | jq -r ".machines[\"$machine\"] | select(.user and .user != \"\") | .user")
ProxyJump_active=$(echo "$config_data" | jq -r ".machines[\"$machine\"].ProxyJump // empty")

# Check if user and ip fields in machine selected
if [[ -z "$ip" || -z "$user" ]]; then
    echo ""
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}"
    echo -e "The ${COLOR_CYAN}ip${COLOR_RESET} or ${COLOR_CYAN}user${COLOR_RESET} for the selected machine could not be found"
    echo -e "Check that the machine ${COLOR_GREEN}($machine)${COLOR_RESET} has the required fields ${COLOR_CYAN}ip${COLOR_RESET} and ${COLOR_CYAN}user${COLOR_RESET} in the configuration file"
    echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
    read
    exit 1
fi

# Check if ProxyJump is enabled and get details if it is
if [[ -n "$ProxyJump_active" ]]; then
    pf_user=$(echo "$config_data" | jq -r ".machines[\"$machine\"].ProxyJump.user")
    pf_ip=$(echo "$config_data" | jq -r ".machines[\"$machine\"].ProxyJump.ip")

    # Rsync backup command
    rsync_command_prefix="sudo rsync -aAXvz --progress --delete -e '\''ssh -o ProxyJump=$pf_user@$pf_ip'\'' $user@$ip:/home ."

    # Check if pf_user and pf_ip fields are populated
    if [[ -z "$pf_ip" || -z "$pf_user" || "$pf_ip" == "null" || "$pf_user" == "null" ]]; then
        echo ""
        echo -e "${COLOR_RED}ERROR${COLOR_RESET}"
        echo -e "The ${COLOR_CYAN}ProxyJump: ip${COLOR_RESET} or ${COLOR_CYAN}ProxyJump: user${COLOR_RESET} for the selected machine could not be found"
        echo -e "Check that the machine ${COLOR_GREEN}($machine)${COLOR_RESET} has the required fields ${COLOR_CYAN}ProxyJump: ip${COLOR_RESET} and ${COLOR_CYAN}ProxyJump: user${COLOR_RESET} in the configuration file."
        echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
        read
        exit 1
    fi

    echo ""
    echo -e "Connecting to ${COLOR_GREEN}$machine${COLOR_RESET} (${COLOR_CYAN}$ip${COLOR_RESET}) as (${COLOR_CYAN}$user${COLOR_RESET})"
    echo -e "Using ${COLOR_GREEN}ProxyJump${COLOR_RESET} (${COLOR_CYAN}$pf_ip${COLOR_RESET}) as (${COLOR_CYAN}$pf_user${COLOR_RESET})"
    echo -e "Maximum timeout ${COLOR_CYAN}$connect_timeout seconds${COLOR_RESET}"
    echo "-----------------------"
else
    # Rsync backup command
    rsync_command_prefix="sudo rsync -aAXvz --progress --delete $user@$ip:/home ."

    echo ""
    echo -e "Connecting to ${COLOR_GREEN}$machine${COLOR_RESET} (${COLOR_CYAN}$ip${COLOR_RESET}) as (${COLOR_CYAN}$user${COLOR_RESET})"
    echo -e "Maximum timeout ${COLOR_CYAN}$connect_timeout seconds${COLOR_RESET}"
    echo "-----------------------"
fi




# SSH key management functions
check_ssh_key() {
    if [[ -f "$HOME/.ssh/id_rsa" && -f "$HOME/.ssh/id_rsa.pub" ]]; then
        # Check if keys exist in the default Windows SSH directory
        if [ "$FROM_WINDOWS" = "true" ]; then
            WIN_SSH_PATH="/mnt/c/Users/$WIN_USER/.ssh"
            if [[ -f "$WIN_SSH_PATH/id_rsa" && -f "$WIN_SSH_PATH/id_rsa.pub" ]]; then
                return 0 # Keys exist in Windows
            else
                copy_ssh_keys_to_windows
                return 0 # Keys exist
            fi
        else
            return 0  # Keys exist
        fi
    else
        # Check if keys exist in the default Windows SSH directory
        if [ "$FROM_WINDOWS" = "true" ]; then
            WIN_SSH_PATH="/mnt/c/Users/$WIN_USER/.ssh"
            if [[ -f "$WIN_SSH_PATH/id_rsa" && -f "$WIN_SSH_PATH/id_rsa.pub" ]]; then
                echo -e "${COLOR_CYAN}SSH keys${COLOR_RESET} found in Windows directory - ${COLOR_CYAN}$WIN_SSH_PATH${COLOR_RESET}"
                echo -e "Copying to WSL..."
                
                # Copy the keys from Windows to WSL
                cp "$WIN_SSH_PATH/id_rsa" "$HOME/.ssh/id_rsa"
                cp "$WIN_SSH_PATH/id_rsa.pub" "$HOME/.ssh/id_rsa.pub"
                
                # Change ownership to the WSL user
                chown "$USER":"$USER" "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_rsa.pub"
                
                # Set the appropriate permissions
                chmod 600 "$HOME/.ssh/id_rsa"
                chmod 644 "$HOME/.ssh/id_rsa.pub"
                
                echo -e "${COLOR_CYAN}SSH keys${COLOR_CYAN} ${COLOR_GREEN}successfully${COLOR_RESET} copied in ${COLOR_GREEN}WSL${COLOR_RESET}"
                return 0  # Keys exist now in WSL
            else
                return 1  # Keys do not exist
            fi
        else
            return 1  # Keys do not exist
        fi
    fi
}

generate_ssh_key() {
    echo ""
    echo -e "No ${COLOR_CYAN}SSH key${COLOR_RESET} was found at ${COLOR_CYAN}$HOME/.ssh/id_rsa${COLOR_RESET}"
    if [ "$FROM_WINDOWS" = "true" ]; then
        echo -e "No ${COLOR_CYAN}SSH key${COLOR_RESET} was found at ${COLOR_CYAN}/mnt/c/Users/$WIN_USER/.ssh${COLOR_RESET}"
    fi
    read -p "Do you want to create an SSH key now? (y/n): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        if [[ $? -eq 0 ]]; then
            echo ""
            echo -e "${COLOR_CYAN}SSH key${COLOR_RESET} created ${COLOR_GREEN}successfully${COLOR_RESET}"
            # Check if the script is run from Windows
            if [ "$FROM_WINDOWS" = "true" ]; then
                copy_ssh_keys_to_windows
            fi
        else
            echo -e "${COLOR_RED}ERROR${COLOR_RESET} creating the ${COLOR_CYAN}SSH key${COLOR_RESET}"
            echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
            read 
            exit 1
        fi
    else
        echo ""
        echo -e "${COLOR_RED}ERROR${COLOR_RESET}"
        echo -e "Cannot continue without an ${COLOR_CYAN}SSH key${COLOR_RESET}"
        echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
        read
        exit 1
    fi
}

copy_ssh_key_to_remote() {
    echo -e "Copying the ${COLOR_CYAN}public key${COLOR_RESET} to the remote server..."
    echo -e "Enter your ${COLOR_GREEN}password${COLOR_RESET} below..."
    if [[ -n "$ProxyJump_active" ]]; then
        ssh-copy-id -o ProxyJump=$pf_user@$pf_ip -o ConnectTimeout=$connect_timeout $user@$ip
    else
        ssh-copy-id -o ConnectTimeout=$connect_timeout $user@$ip
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "${COLOR_CYAN}Public key${COLOR_RESET} copied ${COLOR_GREEN}successfully${COLOR_RESET} to the remote server"
    else
        echo -e "${COLOR_RED}ERROR${COLOR_RESET} copying the ${COLOR_CYAN}public key${COLOR_RESET} to the remote server (${COLOR_GREEN}$machine${COLOR_RESET})"
        echo -e "Check that the ip (${COLOR_CYAN}$ip${COLOR_RESET}) and user (${COLOR_CYAN}$user${COLOR_RESET}) are correct"
        echo -e "Check that the machine (${COLOR_GREEN}$machine${COLOR_RESET}) is accessible with the command - ${COLOR_CYAN}ping $ip${COLOR_RESET}"
        echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
        read
        exit 1
    fi
}

copy_ssh_keys_to_windows() {
    # Windows SSH directory
    local win_ssh_path="/mnt/c/Users/$WIN_USER/.ssh"
    
    # Create Windows .ssh directory if it doesn't exist
    if [ ! -d "$win_ssh_path" ]; then
        echo -e "${COLOR_CYAN}Creating Windows SSH directory...${COLOR_RESET}"
        mkdir -p "$win_ssh_path"
    fi
    
    # Copy keys to Windows, avoiding overwrites
    cp --update=none $HOME/.ssh/* "$win_ssh_path/"
    chmod 600 "$win_ssh_path/id_rsa"
    chmod 644 "$win_ssh_path/id_rsa.pub"
    echo -e "${COLOR_CYAN}SSH key${COLOR_RESET} copied to Windows .ssh directory ${COLOR_CYAN}($win_ssh_path)${COLOR_RESET} ${COLOR_GREEN}successfully${COLOR_RESET}"
}


# Prepare the SSH command
if [[ "$use_ssh_key" == "True" || "$use_ssh_key" == "true" ]]; then
    # Check if SSH keys exist
    if ! check_ssh_key; then
        generate_ssh_key
    fi

    # Attempt to connect without password to check if the key is already authorized
    if [[ -n "$ProxyJump_active" ]]; then
        # Step 1: Check and copy key to the proxy server if ProxyJump is active
        ssh -o BatchMode=yes -o ConnectTimeout=$connect_timeout $pf_user@$pf_ip 'exit' 2>/dev/null
        if [[ $? -ne 0 ]]; then
            # Copy key to proxy server
            echo ""
            echo -e "The ${COLOR_CYAN}public key${COLOR_RESET} is not authorized on the proxy server"
            echo -e "Copying the ${COLOR_CYAN}public key${COLOR_RESET} to the proxy server..."
            echo -e "Enter your ${COLOR_GREEN}password${COLOR_RESET} below..."
            ssh-copy-id -o ConnectTimeout=$connect_timeout $pf_user@$pf_ip
            if [[ $? -eq 0 ]]; then
                echo -e "${COLOR_CYAN}Public key${COLOR_RESET} copied ${COLOR_GREEN}successfully${COLOR_RESET} to the ProxyJump server (${COLOR_GREEN}$pf_ip${COLOR_RESET})"
            else
                echo -e "${COLOR_RED}ERROR${COLOR_RESET} copying the ${COLOR_CYAN}public key${COLOR_RESET} to the ProxyJump server (${COLOR_GREEN}$pf_ip${COLOR_RESET})"
                echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
                read
                exit 1
            fi
        fi
        # Step 2: Check if key is in the final server
        ssh -o ProxyJump=$pf_user@$pf_ip -o BatchMode=yes -o ConnectTimeout=$connect_timeout $user@$ip 'exit' 2>/dev/null
    else
        ssh -o BatchMode=yes -o ConnectTimeout=$connect_timeout $user@$ip 'exit' 2>/dev/null
    fi

    # Copy key to remote server
    if [[ $? -ne 0 ]]; then
        echo ""
        echo -e "The ${COLOR_CYAN}public key${COLOR_RESET} is not authorized on the remote server"
        copy_ssh_key_to_remote
    fi

    # Now connect using the SSH key
    ssh_command="ssh -i $HOME/.ssh/id_rsa -o ConnectTimeout=$connect_timeout -t"
else
    # Normal password-based connection
    ssh_command="ssh -o ConnectTimeout=$connect_timeout -o PubkeyAuthentication=no -o PreferredAuthentications=password -o IdentitiesOnly=yes -t"
fi

# Post forwarding option if exist
if [[ -n "$ProxyJump_active" ]]; then
    # Connect through intermediate machine
    ssh_command="$ssh_command -J $pf_user@$pf_ip $user@$ip"
    scp_command_prefix="scp -o ProxyJump=$pf_user@$pf_ip"
else
    # Direct SSH connection
    ssh_command="$ssh_command $user@$ip"
    scp_command_prefix="scp"
fi

# Check if export_commands_to_machine is True or False
if [[ "$export_commands_to_machine" == "true" ]]; then
    # If True, run the SSH with the function of commands
    echo ""
    $ssh_command "
    bash -c '
    commands_of_interest() {
        echo "-----------------------"
        echo "Commands of interest:"

        # Category: Transfer files between machines
        echo -e \" - \033[1;32mTransfer files between machines\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Send a file to the remote machine (run on local machine)\";
        echo -e \"    \033[1;36m $scp_command_prefix example.zip $user@$ip:example_folder/\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Retrieve a file from the remote machine (run on local machine)\";
        echo -e \"    \033[1;36m $scp_command_prefix $user@$ip:example/example.zip .\033[0m\";
        echo -e \"   \033[1;32m  ----\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Create zip of a folder\";
        echo -e \"    \033[1;36m zip -r my_project.zip my_project/\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Unzip file\";
        echo -e \"    \033[1;36m unzip file.zip -d destination_folder\033[0m\";
        echo -e \"   \033[1;32m  ----\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Displays disk usage for each top-level folder in the current directory\";
        echo -e \"    \033[1;36m sudo du -h --max-depth=1\033[0m\";
        echo -e \"      \033[1;31m·\033[0m Shows sizes in human-readable format \033[1;36m-h\033[0m\"
        echo -e \"      \033[1;31m·\033[0m Limits output to top-level folders   \033[1;36m--max-depth=1\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Create or synchronize backup from the remote machine (run on local machine)\";
        echo -e \"    \033[1;36m $rsync_command_prefix\033[0m\";
        echo -e \"      \033[1;31m·\033[0m Test backup without copying      \033[1;36m--dry-run\033[0m\";
        echo -e \"      \033[1;31m·\033[0m Exclude hidden and config files  \033[1;36m--exclude='\''.*'\''\033[0m\"
        echo -e \"      \033[1;31m·\033[0m Exclude paths defined in file    \033[1;36m--exclude-from=<file>\033[0m\"
        echo -e \"      \033[1;31m·\033[0m Removes files in the destination \033[1;36m--delete\033[0m\";

        # Category: Manage processes
        echo ""
        echo -e \" - \033[1;32mManage processes\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Run script in the background redirecting output to a log\";
        echo -e \"    \033[1;36m nohup python3 -u train.py ^> train.log ^&\033[0m\";
        echo -e \"   \033[1;31m#\033[0m View live console using log file\";
        echo -e \"    \033[1;36m tail -f train.log\033[0m\";
        echo -e \"   \033[1;32m  ----\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Find general pid\";
        echo -e \"    \033[1;36m ps\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Find specific pid (python processes from the user)\";
        echo -e \"    \033[1;36m ps -aux | grep python | grep $user | grep -v grep\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Find pid of process using the GPU\";
        echo -e \"    \033[1;36m nvidia-smi\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Kill process by pid\";
        echo -e \"    \033[1;36m kill -9 pid\033[0m\";

        # Category: Manage the remote machine
        echo ""
        echo -e \" - \033[1;32mManage the remote machine\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Add a new user\";
        echo -e \"    \033[1;36m sudo useradd -m -d /home/newuser -s /bin/bash newuser\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Change a user password\";
        echo -e \"    \033[1;36m sudo passwd newuser\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Force password change\";
        echo -e \"    \033[1;36m sudo chage -d 0 newuser\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Delete a user\";
        echo -e \"    \033[1;36m sudo userdel -r newuser\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Check my user permissions\";
        echo -e \"    \033[1;36m whoami\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Check users with sudo permissions\";
        echo -e \"    \033[1;36m getent group sudo\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Grant sudo privileges to a user\";
        echo -e \"    \033[1;36m sudo usermod -aG sudo newuser\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Revoke sudo privileges from a user\";
        echo -e \"    \033[1;36m sudo deluser newuser sudo\033[0m\";

        # Category: Manage GPU and Pytorch
        echo ""
        echo -e \" - \033[1;32mManage GPU, CUDA and Pytorch \033[0m\";
        echo -e \"   \033[1;31m#\033[0m Find processes on the GPU, see available memory, etc\";
        echo -e \"    \033[1;36m nvidia-smi\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Check GPUs available and if they are virtualized\";
        echo -e \"    \033[1;36m lspci | grep -i vga\033[0m\";
        echo -e \"   \033[1;31m#\033[0m Find the NVIDIA driver installer on the system\";
        echo -e \"    \033[1;36m sudo find / -name "NVIDIA\*.run"\033[0m\";

        echo ""

    };
    export -f commands_of_interest;
    clear
    echo "-----------------------"
    echo -e \"Run the command (\033[1;36mcommands_of_interest\033[0m) to display a list of useful commands for:\";
    echo -e \"   \033[1;31m-\033[0m Transferring files between machines\";
    echo -e \"   \033[1;31m-\033[0m Managing processes\";
    echo -e \"   \033[1;31m-\033[0m Managing the remote machine\";
    echo -e \"   \033[1;31m-\033[0m Managing GPU, CUDA and Pytorch\";
    echo -e \"   \033[1;31m-\033[0m ...\";
    echo ""
    exec bash
    '
    "
else
    # If False, run the normal SSH command
    echo ""
    $ssh_command
fi

# Check if the SSH was successful
if [[ $? -ne 0 ]]; then
    echo ""
    echo -e "${COLOR_RED}ERROR${COLOR_RESET}: Unable to connect to the machine (${COLOR_GREEN}$machine${COLOR_RESET})"
    echo -e "Verify that the ip (${COLOR_CYAN}$ip${COLOR_RESET}) and user (${COLOR_CYAN}$user${COLOR_RESET}) are correct"
    echo -e "Verify that the machine (${COLOR_GREEN}$machine${COLOR_RESET}) is accessible with the command - ${COLOR_CYAN}ping $ip${COLOR_RESET}"
    if [[ -n "$ProxyJump_active" ]]; then
        echo -e "Check if connecting to the intermediate machine is possible. You may need to connect to a VPN"
    echo -e "Press ${COLOR_RED}Enter${COLOR_RESET} to close the program"
    read  # This will make the script wait for user input before continuing
fi
