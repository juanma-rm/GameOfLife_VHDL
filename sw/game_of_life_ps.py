#####################################################################################
# Import libraries
#####################################################################################

from pynq import Overlay
from pynq.lib.video import *
from pynq import PL
from pynq import allocate
import numpy as np
import threading
import keyboard
import queue

#####################################################################################
# Key IDs mapping
#####################################################################################

key_mapping = {
    'esc'       : 0,
    'up'        : 1,
    'down'      : 2,
    'left'      : 3,
    'right'     : 4,
    'space'     : 5,
    'c'         : 6,
    'enter'     : 7,
    'backspace' : 8
}

#####################################################################################
# PL thread (takes charge of the PL)
#####################################################################################

def pl_thread(event_queue):

    # Load the overlay

    PL.reset()
    overlay = Overlay("game_of_life.xsa")
    # print(overlay.ip_dict)

    # Configure VDMA (to send frames from PL to PS)

    vdma = overlay.axi_vdma_0
    vdma.readchannel.mode = VideoMode(1280, 720, 24)
    vdma.readchannel.cacheable_frames = False
    vdma.readchannel.start()

    # Configure DisplayPort

    displayport = DisplayPort()
    displayport.modes
    displayport.configure(VideoMode(1280, 720, 24), PIXEL_RGB)

    # Configure DMA (to send key events from PS to PL)

    dma = overlay.axi_dma_0
    dma_send = dma.sendchannel
    data_size = 1
    input_buffer = allocate(shape=(data_size,), dtype=np.uint32)

    # Get frames / display via DP and send key events to the PL

    print("You're already playing. Enjoy!")
    
    while True:

        frame_dp = displayport.newframe()
        frame_dp[:] = vdma.readchannel.readframe()
        displayport.writeframe(frame_dp)
        
        if not event_queue.empty():
            key_name = event_queue.get()
            print(f'Main thread received event: {key_name}')
            # Send to vdma
            if key_name in key_mapping.keys():
                input_buffer[0] = key_mapping.get(key_name)
                dma_send.transfer(input_buffer)

            if key_name.lower() == 'esc':
                vdma.readchannel.stop()
                break   
    
#####################################################################################
# Keyboard thread (takes charge of handling key stroke events and sending them to the PL thread)
#####################################################################################

def keyboard_thread(event_queue):
    while True:
        event = keyboard.read_event(suppress=True)
        if event.event_type == keyboard.KEY_DOWN: # capture event at release
            key_name = event.name
            event_queue.put(key_name)

            if key_name.lower() == 'esc':
                break

#####################################################################################
# Entry point
#####################################################################################
            
# Create a queue for communication between threads
key_event_queue = queue.Queue()

# Create and start the keyboard processing thread
keyboard_thread = threading.Thread(target=keyboard_thread, args=(key_event_queue,))
keyboard_thread.start()

# Run the main thread
pl_thread(key_event_queue)

# Wait for both threads to finish
pl_thread.join()
keyboard_thread.join()
            