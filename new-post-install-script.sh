#!/bin/bash

# Paso 1: Configurar sudo sin pedir contraseña
function paso1() {
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

# Paso 2: Instalación de qemu-guest-agent (confirmación automática)
function paso2() {
    echo "Paso 2: Instalación de qemu-guest-agent."
    sudo apt install -y qemu-guest-agent
    if [ $? -eq 0 ]; then
        echo "qemu-guest-agent instalado correctamente."
    else
        echo "Error en la instalación de qemu-guest-agent."
    fi
}

# Paso 3: Actualización del servidor
function paso3() {
    echo "Paso 3: Actualización del servidor."
    sudo apt update && sudo apt upgrade -y
    if [ $? -eq 0 ]; then
        echo "Actualización completada correctamente."
    else
        echo "Error en la actualización."
    fi
}

# Paso 4: Instalación de utilitarios
function paso4() {
    echo "Paso 4: Instalación de utilitarios."
    sudo apt install -y neofetch speedtest-cli glances cockpit net-tools
    if [ $? -eq 0 ]; then
        echo "Utilitarios instalados correctamente."
    else
        echo "Error en la instalación de utilitarios."
    fi
}

# Paso 5: Sincronización de hora y activación de NTP
function paso5() {
    echo "Paso 5: Sincronización de hora y activación de NTP."
    sudo timedatectl set-timezone America/Guayaquil
    sudo timedatectl set-ntp on
    if [ $? -eq 0 ]; then
        echo "Hora sincronizada y NTP activado correctamente."
    else
        echo "Error al sincronizar la hora o activar NTP."
    fi
}

# Paso 7: Añadir nuevo usuario y agregarlo al grupo sudo
function paso7() {
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

# Paso 8: Redimensionamiento y verificación del disco
function paso8() {
    echo "Paso 8: Redimensionamiento y verificación del disco."
    
    echo "Desactivando swap..."
    sudo swapoff -a
    if [ $? -ne 0 ]; then echo "Error al desactivar swap."; return 1; fi

    echo "Eliminando /swap.img y entrada en /etc/fstab..."
    sudo rm -f /swap.img
    sudo sed -i '/swap.img/d' /etc/fstab

    echo "Redimensionando partición 3 en /dev/sda..."
    sudo parted /dev/sda resizepart 3 100%
    if [ $? -ne 0 ]; then echo "Error al redimensionar la partición."; return 1; fi

    echo "Redimensionando volumen físico en /dev/sda3..."
    sudo pvresize /dev/sda3
    if [ $? -ne 0 ]; then echo "Error al redimensionar el volumen físico."; return 1; fi

    echo "Extendiendo el volumen lógico..."
    sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
    if [ $? -ne 0 ]; then echo "Error al extender el volumen lógico."; return 1; fi

    echo "Redimensionando el sistema de archivos..."
    sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
    if [ $? -ne 0 ]; then echo "Error al redimensionar el sistema de archivos."; return 1; fi

    echo "Mostrando información final del sistema:"
    sudo df -h /
    sudo lvdisplay /dev/ubuntu-vg/ubuntu-lv
    sudo vgdisplay ubuntu-vg

    echo "Redimensionamiento y verificación del disco completados."
}

# Menú interactivo para elegir qué pasos ejecutar
echo "Bienvenido al script post-instalación de la VM, Ricardo."
echo "Selecciona la opción deseada:"
echo "1) Paso 1: Configurar sudo sin pedir contraseña"
echo "2) Paso 2: Instalación de qemu-guest-agent"
echo "3) Paso 3: Actualización del servidor"
echo "4) Paso 4: Instalación de utilitarios"
echo "5) Paso 5: Sincronización de hora y activación de NTP"
echo "7) Paso 7: Añadir nuevo usuario y agregarlo al grupo sudo"
echo "8) Paso 8: Redimensionamiento y verificación del disco"
echo "9) Ejecutar TODOS los pasos"

read -p "Ingresa tu opción: " opcion

case $opcion in
    1)
        paso1
        ;;
    2)
        paso2
        ;;
    3)
        paso3
        ;;
    4)
        paso4
        ;;
    5)
        paso5
        ;;
    7)
        paso7
        ;;
    8)
        paso8
        ;;
    9)
        paso1
        paso2
        paso3
        paso4
        paso5
        paso7
        paso8
        ;;
    *)
        echo "Opción inválida. Ejecuta el script nuevamente y selecciona una opción correcta."
        ;;
esac
