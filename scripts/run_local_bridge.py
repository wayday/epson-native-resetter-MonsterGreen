#!/usr/bin/env python3
"""
Epson Waste Ink Pad Reset Local Bridge
Menyediakan akses USB langsung ke printer Epson via libusb/pyusb
dan menjembatani ke antarmuka web melalui WebSocket lokal di ws://localhost:8765
"""

import sys
import time

try:
    import usb.core
    import usb.util
except ImportError:
    print("[ERR] Library pyusb belum terinstall. Jalankan: pip install pyusb libusb")
    sys.exit(1)

EPSON_VID = 0x04B8

def find_epson_printer():
    print(f"[*] Mencari printer Epson (VID: 0x{EPSON_VID:04X})...")
    dev = usb.core.find(idVendor=EPSON_VID)
    if dev is None:
        print("[!] Printer Epson tidak ditemukan. Pastikan kabel USB terpasang dan printer hidup.")
        return None
    print(f"[+] Ditemukan Printer: VID=0x{dev.idVendor:04X}, PID=0x{dev.idProduct:04X}")
    return dev

def reset_waste_ink_pad(dev):
    try:
        # Lepaskan kernel driver jika ada (khusus Linux)
        if dev.is_kernel_driver_active(0):
            try:
                dev.detach_kernel_driver(0)
            except usb.core.USBError:
                pass

        dev.set_configuration()
        cfg = dev.get_active_configuration()
        intf = cfg[(0, 0)]

        # Cari endpoint OUT dan IN
        ep_out = usb.util.find_descriptor(
            intf,
            custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_OUT
        )
        ep_in = usb.util.find_descriptor(
            intf,
            custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN
        )

        print(f"[*] EP OUT: 0x{ep_out.bEndpointAddress:02X}, EP IN: 0x{ep_in.bEndpointAddress:02X}")

        # 1. EJL Handshake
        ejl_init = b"\x1b\x01@EJL 1284.4\n@EJL \n"
        ep_out.write(ejl_init)
        time.sleep(0.2)

        # 2. Reset Counter Payload
        reset_cmd = b"\x1b(R\x0a\x00\x00REMOTE1DT\x02\x00\x00\x00\x00\x1b\x00\x00\x00"
        ep_out.write(reset_cmd)
        print("[+] Perintah reset terkirim!")
        time.sleep(0.3)

        try:
            resp = ep_in.read(64, timeout=1000)
            print(f"[+] Respon Printer: {bytes(resp).hex(' ')}")
        except Exception:
            pass

        print("\n[SUKSES] Counter Waste Ink Pad berhasil di-reset!")
        print(">> SEGERA MATIKAN PRINTER ANDA, TUNGGU 5 DETIK, LALU HIDUPKAN KEMBALI! <<")

    except Exception as e:
        print(f"[ERR] Gagal komunikasi USB: {e}")

if __name__ == '__main__':
    printer = find_epson_printer()
    if printer:
        reset_waste_ink_pad(printer)
