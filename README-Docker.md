# GACS — Docker Install (Ubuntu 18–24)

![Ubuntu](https://img.shields.io/badge/Ubuntu-18.04%20%E2%80%93%2024.04-E95420?logo=ubuntu&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-Engine%20%2B%20Compose-2496ED?logo=docker&logoColor=white) ![MongoDB](https://img.shields.io/badge/MongoDB-8.0-47A248?logo=mongodb&logoColor=white)

> **Untuk** Ubuntu **18.04 hingga 24.04** dengan **Docker** & **Docker Compose**. Menggunakan native bridge network — tanpa ZeroTier.

---

## Catatan
Panduan ini menginstal **GenieACS** menggunakan Docker/Compose beserta virtual parameter dari repo yang sudah tersedia.

---

## Prasyarat
- Akses **root** ke VPS / Mini PC
- Jika ada firewall pastikan port yang terbuka: **7547/TCP (CWMP), 7557/TCP (NBI), 7567/TCP (FS), 3000/TCP (UI)**

---

## Instalasi GenieACS Docker
```bash
# 1) Masuk sebagai root
sudo su
```
```bash
# 2) Update singkat
apt update -y && apt upgrade -y && apt autoremove -y
```
```bash
# 3) Pasang Docker + Compose (script otomatis)
bash <(curl -s https://raw.githubusercontent.com/safrinnetwork/Auto-Install-Docker/main/install.sh)
```
```bash
# 4) Download Script GACS
git clone https://github.com/forsuregoodpeople/GACS-Ubuntu-22.04
```
```bash
# 5) Masuk ke folder GACS
cd GACS-Ubuntu-22.04
```
```bash
# 6) Jalankan installer Docker
chmod +x install-genieacs-docker.sh
./install-genieacs-docker.sh
```

---

## Install Virtual Parameter (Docker)
Untuk instal parameter `config`, `virtualParameters`, `presets`, dan `provisions`:

```bash
# 1) Salin folder parameter ke container
#   (dari direktori repo GACS)
docker cp ./parameter/ genieacs-server:/tmp/
```
```bash
# 2) Restore parameter ke database 'genieacs'
docker exec genieacs-server mongorestore --db genieacs --collection config              --drop /tmp/parameter/config.bson
docker exec genieacs-server mongorestore --db genieacs --collection virtualParameters   --drop /tmp/parameter/virtualParameters.bson
docker exec genieacs-server mongorestore --db genieacs --collection presets             --drop /tmp/parameter/presets.bson
docker exec genieacs-server mongorestore --db genieacs --collection provisions          --drop /tmp/parameter/provisions.bson
```
```bash
# 3) Restart layanan (Compose)
cd /opt/genieacs-docker && docker-compose restart && sleep 15
```

## Penting (Provisions → Inform)
Setelah **menambahkan parameter login**, buka **GenieACS UI → Provisions → Show (Inform)** dan perbarui:
- `const url`
- `const AcsUser`
- `const AcsPass`
- `let ConnReqUser`
- `const ConnReqPass`

Simpan perubahan agar **Inform/Connection Request** sesuai dengan kredensial dan alamat ACS Anda.

---

## Konfigurasi MikroTik (TR‑069)
1. Pastikan ada **VLAN** yang terhubung ke **ONU**.
2. Contoh rule firewall (sesuaikan `IP_VPS`, nama interface, dan port request ONU — contoh **58000**):

```bash
/ip firewall filter add chain=forward connection-state=established,related action=accept
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_VPS] \
  in-interface=[NAMA_INTERFACE_VLAN] dst-port=7547 comment="ONU -> ACS CWMP"
/ip firewall filter add chain=forward action=accept protocol=tcp src-address=[IP_VPS] \
  out-interface=[NAMA_INTERFACE_VLAN] dst-port=58000 comment="ACS -> ONU Connection Request"
```
> **Catatan:** Port **58000** adalah contoh Connection Request URL dari ONU — silakan sesuaikan dengan perangkat Anda.

---

## Video Panduan
- **Docker** https://youtu.be/Jt0bW3Yq2d8?feature=shared
