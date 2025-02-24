#!/bin/bash
# Script reestructurado para post-instalación de la VM

##########################
# Funciones Auxiliares
##########################
ask_optional() {
    # Pregunta si desea ejecutar un paso opcional y lo ejecuta si la respuesta es afirmativa.
    # Uso: ask_optional "Mensaje" nombre_de_funcion
    local prompt="$1"
    local func="$2"
    read -p "$prompt (s/n): " resp
    if [[ "$resp" =~ ^[Ss]$ ]]; then
        $func
    else
        echo "Omitido: $prompt"
    fi
}

##########################
# Pasos Obligatorios (1-5)
##########################
step1() {
    echo "Paso 1: Configurar sudo sin pedir contraseña."
    read -sp "Ingresa tu contraseña de sudo: " sudo_password
    echo ""
    echo "$sudo_password" | sudo -S bash -c 'echo "$(logname) ALL=(ALL:ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)'
    if [ $? -eq 0 ]; then
        echo "Configuración de sudo completada exitosamente."
    else
        echo "Error al configurar sudo."
    fi
}

step2() {
    echo "Paso 2: Instalación de qemu-guest-agent."
    sudo apt install -y qemu-guest-agent
    if [ $? -eq 0 ]; then
        echo "qemu-guest-agent instalado correctamente."
    else
        echo "Error en la instalación de qemu-guest-agent."
    fi
}

step3() {
    echo "Paso 3: Actualización del servidor."
    sudo apt update && sudo apt upgrade -y
    if [ $? -eq 0 ]; then
        echo "Actualización completada correctamente."
    else
        echo "Error en la actualización."
    fi
}

step4() {
    echo "Paso 4: Instalación de utilitarios."
    sudo apt install -y neofetch speedtest-cli glances cockpit net-tools
    if [ $? -eq 0 ]; then
        echo "Utilitarios instalados correctamente."
    else
        echo "Error en la instalación de utilitarios."
    fi
}

step5() {
    echo "Paso 5: Sincronización de hora y activación de NTP."
    sudo timedatectl set-timezone America/Guayaquil
    sudo timedatectl set-ntp on
    if [ $? -eq 0 ]; then
        echo "Hora sincronizada y NTP activado correctamente."
    else
        echo "Error al sincronizar la hora o activar NTP."
    fi
}

##########################
# Pasos Opcionales (6-9)
##########################
step6() {
    echo "Paso 6: Instalación de Docker."
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce
    if [ $? -eq 0 ]; then
        echo "Docker instalado correctamente."
    else
        echo "Error en la instalación de Docker."
    fi
}

step7() {
    echo "Paso 7: Añadir nuevo usuario y agregarlo al grupo sudo."
    read -p "Ingresa el nombre del nuevo usuario: " newuser
    sudo adduser --gecos "" --disabled-password "$newuser"
    echo "$newuser:$newuser" | sudo chpasswd
    sudo usermod -aG sudo "$newuser"
    if [ $? -eq 0 ]; then
        echo "Usuario '$newuser' añadido y agregado al grupo sudo correctamente."
    else
        echo "Error al añadir el usuario o agregarlo al grupo sudo."
    fi
}

step8() {
    echo "Paso 8: Redimensionamiento y verificación del disco."
    echo "Desactivando swap..."
    sudo swapoff -a || { echo "Error al desactivar swap."; return 1; }
    echo "Eliminando /swap.img y entrada en /etc/fstab..."
    sudo rm -f /swap.img
    sudo sed -i '/swap.img/d' /etc/fstab
    echo "Redimensionando partición 3 en /dev/sda..."
    sudo parted /dev/sda resizepart 3 100% || { echo "Error al redimensionar la partición."; return 1; }
    echo "Redimensionando volumen físico en /dev/sda3..."
    sudo pvresize /dev/sda3 || { echo "Error al redimensionar el volumen físico."; return 1; }
    echo "Extendiendo el volumen lógico..."
    sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv || { echo "Error al extender el volumen lógico."; return 1; }
    echo "Redimensionando el sistema de archivos..."
    sudo resize2fs /dev/ubuntu-vg/ubuntu-lv || { echo "Error al redimensionar el sistema de archivos."; return 1; }
    echo "Mostrando información final del sistema:"
    sudo df -h /
    sudo lvdisplay /dev/ubuntu-vg/ubuntu-lv
    sudo vgdisplay ubuntu-vg
    echo "Redimensionamiento y verificación del disco completados."
}

step9() {
    echo "Paso 9: Instalación de Portainer CE."
    sudo docker volume create portainer_data
    sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest
    if [ $? -eq 0 ]; then
        echo "Portainer CE instalado y en ejecución."
    else
        echo "Error en la instalación de Portainer CE."
    fi
}

##########################
# Funciones de Ejecución
##########################
run_mandatory_steps() {
    echo "Ejecutando los pasos obligatorios (1-5)..."
    step1; step2; step3; step4; step5
}

run_optional_steps() {
    echo "Ahora, seleccione los pasos opcionales que desea ejecutar:"
    echo "1) Paso 6: Instalación de Docker"
    echo "2) Paso 7: Añadir nuevo usuario"
    echo "3) Paso 8: Redimensionamiento del disco"
    echo "4) Paso 9: Instalación de Portainer CE"
    read -p "Ingrese los números de los pasos a ejecutar, separados por espacio (ej. 1 3): " -a opts
    for opt in "${opts[@]}"; do
        case $opt in
            1) step6 ;;
            2) step7 ;;
            3) step8 ;;
            4) step9 ;;
            *) echo "Opción $opt no válida." ;;
        esac
    done
}

##########################
# Menú Principal
##########################
main() {
    echo "Bienvenido al script post-instalación de la VM, Ricardo."
    echo "Seleccione el modo de ejecución:"
    echo "  1) Ejecutar TODOS los pasos (Obligatorios + Opcionales)"
    echo "  2) Ejecutar solo los pasos obligatorios (1-5)"
    echo "  3) Ejecutar solo los pasos opcionales"
    read -p "Ingrese su opción (1/2/3): " mode
    case $mode in
        1)
            run_mandatory_steps
            echo "Se procederá a preguntar por los pasos opcionales."
            ask_optional "¿Desea ejecutar la instalación de Docker (Paso 6)?" step6
            ask_optional "¿Desea añadir un nuevo usuario (Paso 7)?" step7
            ask_optional "¿Desea ejecutar el redimensionamiento del disco (Paso 8)?" step8
            ask_optional "¿Desea instalar Portainer CE (Paso 9)?" step9
            ;;
        2)
            run_mandatory_steps
            ;;
        3)
            run_optional_steps
            ;;
        *)
            echo "Opción inválida."
            ;;
    esac
}

# Iniciar el script
main
