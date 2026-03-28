"""
Virtual serial port bridge for UART.
Replaces socat for connecting picocom to Verilog testbench.
Socat is is a Unix command-line tool that creates bidirectional data relays between two endpoints.

Usage:
    Terminal #1: python3 uart_bridge.py
    Terminal #2: picocom -b 115200 /tmp/uart_pty
    Terminal #3: vvp firmware_tb.vvp
"""

import os
import pty   # Pseudo-terminal module
import tty   # Convenience functions for changing a terminal's mode
import select

SP_FILE = "/tmp/vserial_sp"     # Simulation -> Python
PS_FILE = "/tmp/vserial_ps"     # Python -> Simulation
PTY_LINK = "/tmp/uart_pty"      # Pointer to actual PTY device

# Creates a pseudo-terminal for picocom to connect to it


def setup_pty():
    # Pseudo-terminal is composed of two endpoints: a master and a slave
    # The terminal emulator reads output from and writes input to the master
    # Reads user input and writes program output through it
    # Data written to the master appears as input to the slave,
    # and anything written to the slave can be read from the master

    # Creates the PTY pair and returns two file descriptors on both endpoints
    master_fd, slave_fd = pty.openpty()

    # Converts the slave's fd number into its actual filesystem path
    slave_name = os.ttyname(slave_fd)

    # Puts the slave into raw mode, which disables the terminal driver's default behaviors:
    # no line buffering, no echo, no special character handling
    tty.setraw(slave_fd)

    # Deletes the symlink if it already exists
    try:
        os.remove(PTY_LINK)
    except:
        pass

    # Creates a symlink. A symlink (symbolic link) is a file that just points to another file
    os.symlink(slave_fd, PTY_LINK)

    return master_fd, slave_fd, slave_name

# Resets simulation files


def reset_sim_files():
    # Remove old files if they exist
    for filepath in [SP_FILE, PS_FILE]:
        try:
            os.remove(filepath)
        except:
            pass

    # Create blank files
    open(SP_FILE, 'w').close()
    open(PS_FILE, 'w').close()

    # Confirm that resets occurred
    print(f"[RESET] {SP_FILE}")
    print(f"[RESET] {PS_FILE}")


def main():
    print("="*50)
    print("UART Bridge")
    print("="*50)

    # Setup PTY for picocom
    master_fd, slave_fd, slave_name = setup_pty()
    print(f"\nPTY created: {slave_name}")
    print(f"Symlink: {PTY_LINK} -> {slave_name}")
    print(
        f"\nConnect with: picocom -b 115200 --omap crlf --imap lfcrlf --echo {PTY_LINK}")

    # Setup simulation file interface
    reset_sim_files()

    print("\nReady! Start your simulation now: vvp firmware_tb.vvp")
    print("Press Ctrl+C to stop.\n")

    # Tracks how many bytes of SP_FILE have already been read
    sp_pos = 0

    try:
        while True:
            # Watches the PTY master and waits up to 0.01 seconds for activity
            readable, _, _ = select.select([master_fd], [], [], 0.01)
            if master_fd in readable:
                try:
                    data = os.read(master_fd, 1024)
                    with open(PS_FILE, 'ab') as f:
                        f.write(data)
                        f.flush()            # Flushes application buffers to kernel
                        # Flushes from the kernel buffer all the way to disk, so Verilog sees it immediately
                        os.fsync(f.fileno())
                except OSError as e:
                    print(f"[ERROR] PTY read failed: {e}")
                    break

            try:
                file_size = os.path.getsize(SP_FILE)
                if file_size > sp_pos:
                    with open(SP_FILE, "rb") as f:
                        f.seek(sp_pos)  # jumps past already-read data
                        data = os.read(file_size - sp_pos)
                        # reads only the new bytes and writes them to the PTY master
                        os.write(master_fd, data)
                        sp_pos = file_size
            except OSError:
                pass
    except KeyboardInterrupt:
        print("\n\nShutting down bridge...")

    finally:
        # Cleanup
        os.close(master_fd)
        os.close(slave_fd)

        for filename in [SP_FILE, PS_FILE, PTY_LINK]:
            try:
                os.remove(filename)
            except:
                pass

        print("Bridge closed.")


if __name__ == "__main__":
    main()
