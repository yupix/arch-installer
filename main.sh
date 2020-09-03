#!/usr/bin/env bash

#--------------------------------<<ARCHINSTALLER INFO>>--------------------------------#
#version
ARCH_INSTALLER_VERSION="100"
#Edition
#FULL=完全構成
#MIDIUM=通常構成
#SMALL=最小構成
ARCH_INSTALLER_EDITION="FULL"
#Repository
INTREPOURL="https://repo.akarinext.org/"

##USER DATA
home_directory=$(echo ~$USERNAME)
USER=$(whoami)

cryptography=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 | sort | uniq)
chars="/-\|"
#MAX RETRY
RETRYMAX="3"
#--------------------------------<<ECHO COLOR LIST>>-----------------------------#
##WHITE BOLD
ECHO_WHITE_BOLD_COLOR="\033[1;37m"
##RED
ECHO_RED_COLOR="\033[1;31m"
##GREEN
ECHO_GREEN_COLOR="\033[1;32m"
##YELLOW
ECHO_YELLOW_COLOR="\033[1;33m"
##BLUE
ECHO_BLUE_COLOR="\e[34;1m"
##WHITE
ECHO_WHITE_COLOR="\033[1;37m"
##EXIT
ECHO_COLOR_EXIT="\033[0;39m"
#--------------------------------------------------------------------------------#


#fdisk -l

run_spinner() {
	for ((n = 0; n < ${#chars}; n++)); do
		sleep 0.05
		echo -en "${chars:$n:1} ${spinner_progress_status} " "\r"
	done
}

echo "1.FirstSetup"
read -p ">" input_data

case $input_data in
1)
	spinner_progress_status="Creating Partision..."
	run_spinner
	sgdisk -z /dev/sda
	timeout 10 dd if=/dev/zero of=/dev/sda bs=4M
	sgdisk -n 1:0:+100M -t 1:ef00 -c 1:"EFI System" /dev/sda
	sgdisk -n 2:0:+1024M -t 2:8300 -c 2:"Linux filesystem" /dev/sda
	sgdisk -n 3:0: -t 3:8300 -c 3:"Linux filesystem" /dev/sda
	echo "Successful Create Partition"
	spinner_progress_status="Starting a Format..."
	run_spinner
	mkfs.vfat -F32 /dev/sda1
	mkfs.ext4 /dev/sda2
	mkfs.ext4 /dev/sda3
	echo "Successful on Format"

	spinner_progress_status="Starting a Format..."
	run_spinner
	echo "Starting Mount..."
	mount /dev/sda3 /mnt
	mkdir /mnt/boot
	mount /dev/sda2 /mnt/boot
	mkdir /mnt/boot/efi
	mount /dev/sda1 /mnt/boot/efi
	echo "Successful on Mount..."

	#MIRRORLIST
	echo "Please Input used Mirror URL (Default: http://ftp.tsukuba.wide.ad.jp/Linux/archlinux/\$repo/os/\$arch)"

	read -p ">" input_mirror_data
	input_mirror_data=${input_mirror_data:-http://ftp.tsukuba.wide.ad.jp/Linux/archlinux/\$repo/os/\$arch}
	sed -i '6a Server = '${input_mirror_data}'' /etc/pacman.d/mirrorlist

	sed -i '6a ## JAPAN' /etc/pacman.d/mirrorlist

	echo "Please Input used editor name (Default: nano)"

	read -p ">" input_editor_data
	input_editor_data=${input_editor_data:-nano}

	echo "Please Input used Other package"
	read -p ">" input_custompackage_data

	pacstrap /mnt base base-devel linux linux-firmware grub dosfstools efibootmgr netctl xfsprogs networkmanager pwgen screen unzip wget ${input_editor_data,,} ${input_custompackage_data,,}

	echo "Create fstab"
	genfstab -U /mnt >>/mnt/etc/fstab

	echo "Start chroot"
	echo "Please try again when finished"

	arch-chroot /mnt /bin/bash
	;;
2)

	systemctl enable NetworkManager
	echo "Setup Locale"
	sed -i -e 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
	sed -i -e 's/#ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/g' /etc/locale.gen
	grep -E '^(en_US|ja_JP)\.UTF\-8 UTF\-8' /etc/locale.gen
	locale-gen
	echo "LANG=ja_JP.UTF-8" >/etc/locale.conf
	#Set Timezone
	echo "Please Input Your TimeZone"
	tzselect
	ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
	hwclock --systohc --utc
	echo "Initramfs"
	mkinitcpio -p linux
	echo "Install boot loader"
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch --boot-directory=/boot/efi/EFI --recheck
	grub-mkconfig -o /boot/efi/EFI/grub/grub.cfg

	echo "Please Input Your machin hostname(Default: arch)"
	read -p ">" input_machin_hostname
	input_machin_hostname=${input_machin_hostname:-arch}

	cat <<EOF >/etc/hostname
${input_machin_hostname}
EOF

	echo "Create General User"
	echo "Please Input Your Account Name"
	while [[ -z "${input_account_name}" ]]; do
		read -p ">" input_account_name
		useradd -d /home/${input_account_name} -s /bin/bash -m ${input_account_name}
		passwd ${input_account_name}
		usermod -aG wheel ${input_account_name}
		EDITOR=nano visudo
		#%wheel
		sed -i -e 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
		#ILoveCandy & Color
		sed -i -e 's/#Color/Color/' /etc/pacman.conf
		sed -i '34a ILoveCandy' /etc/pacman.conf
		sed -i -e 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/pacman.conf
		echo "Set Wheel manually"
	done
	while :; do
		echo "Please Input Your Driver Name"

		echo -e "Available:	\n   Host: amd nvidia intel\n   vm: virtualbox\n   other: custom none"
		read -p ">" input_your_driver
		case $input_your_driver in
		[aA][mM][dD])
			pacman -S xf86-video-amdgpu mesa-vdpau libva-vdpau-driver vulkan-radeon
			;;
		[nN][vV][dD][iI][aA])
			pacman -S nvidia
			break
			;;
		[iI][nN][tT][eE][lL])
			pacman -S mesa xf86-video-intel
			break
			;;
		[cC][uU][sS][tT][uU][mM])
			regular_arch_installer_version=$(echo "${ARCH_INSTALLER_VERSION}" | sed -e 's/\(.\)/\1./'g | sed -e 's/.$//')

			while [[ -z "$custom_driver" ]]; do
				custom_driver=$(
					whiptail --backtitle "ArchLinux Installer v${regular_arch_installer_version}" --title "CUSTOM SELECT" --checklist "あなたが好きなお菓子は？" 0 0 0 \
						"AMD" "" OFF \
						"INTEL" "" OFF \
						"NVIDIA" "" OFF 3>&1 1>&2 2>&3
					whiptail --title "final confirmation" --yesno "Are you really sure?" 15 55 3>&1 1>&2 2>&3
				)
			done

			custom_driver=$(echo "$custom_driver" | sed "s/\"//g")

			echo $custom_driver
			exit
			if [[ $custom_driver = "AMD" ]]; then
				pacman -S mesa vulkan-radeon libva-mesa-driver mesa-vdpau
			elif [[ $custom_driver = "INTEL" ]]; then
				pacman -S mesa xf86-video-intel vulkan-intel
			elif [[ $custom_driver = "NVIDIA" ]]; then
				pacman -S nvidia
			fi

			if [ "$custom_driver" = "AMD INTEL" ]; then
				pacman -S mesa vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-intel vulkan-intel
			elif [[ "$custom_driver" = "AMD NVIDIA" ]]; then
				pacman -S mesa vulkan-radeon libva-mesa-driver mesa-vdpau nvidia
			elif [[ "$custom_driver" = "INTEL NVIDIA" ]]; then
				pacman -S nvidia mesa xf86-video-intel vulkan-intel
			elif [[ $custom_driver = "AMD INTEL NVIDIA" ]]; then
				pacman -S mesa vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-intel vulkan-intel nvidia
			fi

			break
			;;
		esac
	done
	pacman -S plasma-meta aria2 adobe-source-han-sans-jp-fonts adobe-source-han-serif-jp-fonts ntfs-3g nemo discord
	sddm --example-config >/etc/sddm.conf
	echo "Please Input Your like Login Theme"
	;;
3)
	systemctl enable sddm
	pacman -S konsole dolphin git unzip
	echo "install blackarch"
	curl -OL http://blackarch.org/strap.sh && sha1sum strap.sh
	chmod 755 ./strap.sh
	cd -
	sudo ./strap.sh
	rm -rf ./strap.sh
	echo "Complete Install Pikaur"
	#yay -S google-chrome visual-studio-code-insiders ttf-ricty
	;;
esac
#SNAP INSTALL
echo "Installing Snapd"
