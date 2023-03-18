# GameOfLife_VHDL

## Table of contents
<ol>
    <li><a href="#About-The-Project">About the project</a></li>
    <li><a href="#Usage">Usage</a></li>
    <li><a href="#Design">Design</a></li>
    <li><a href="#Contact">Contact</a></li>
    <li><a href="#pending_tasks">Potential updates</a></li>
</ol>

## About the project <a name="About-The-Project"></a>

<video width="620" controls><source src="pics/video1.mp4"> </video>

This project consists in a VHDL version of Game of Life, which could be considered more of an experiment and was conceived by mathematician John Conway. The main idea is described as follows. There is a bidimensional grid (let's call it the board, the world, the space dimensions) inhabited by cells (each taking one single space unit) that may born, die or keep its state according to the number of alive neighbors at the given moment. For each new generation (minimum time unit, time resolution, Planck's interval, whatever), each cell's fate shall be determined by the following set of simple rules:
* Any live cell with fewer than two live neighbors dies, as if by underpopulation.
* Any live cell with two or three live neighbors lives on to the next generation.
* Any live cell with more than three live neighbors dies, as if by overpopulation.
* Any dead cell with exactly three live neighbors becomes a live cell, as if by reproduction.

The simulation starts with a certain initial distribution defining which cells are lucky enough to begin alive. This opening scenario is the only single point where the user (let's call the observer or even the cells' God?) makes any contribution. After pressing the play button, each cell's state shall depend on its neighbors' state. 

It looks like a really simple game, right? Well, it actually is. One grid, binary elements (cells that can simply live or die, 1 or 0), some basic rules and the relentless course of time. Then, why wasting a simple nanosecond or even a Planck's interval in such a simple system that evolves and runs on its own, leading to cells being born, cells dimming to the void, emerging patterns that propagate along space and time, get stable forever, oscillate or simply disappear? What if our reality and all our surrounding ecosystems are no more than a (way more sophisticated) set of rules that act on a (undoubtedly larger) set of particles, whose fate is totally predetermined since the origin? Was someone or something there at the very beginning deciding which "cells" would be alive when all this began? Can anything emerge from the void? Is our universe discrete as those cells in Game of Life that can only take a specific position in a grid? How can an entire ecosystem co-operate to keep alive, always chasing the universal effort for surviving one step further? Isn't it impressive how genetics evolves from the void to something alive and self-aware or how disease spreads just because of some rules that were coded in virus game instructions? Could consciousness emerge from the void or from anything other than biological matter, such as silicon? Is it possible to predict the future just by looking at any given previous state and trying to assess the rules the system is based on? Do we really have any chance in deciding which way to take when we find a fork? Are we predetermined, or could we hope for quantum physics from saving us from determinism? Does it make sense at all to question all this? Should we feel special as species for being somehow aware of our position in space and time?

Game of Life does not explain any of the previous questions, but isn't it worth analyzing them basing on so simple rule-based simulation, even if the translation is not applicable?

Summary: the motivation for this project is much simpler than all the biblical text before; I have fun programming and learning and I wanted to keep practising my HDL skills while designing something that drew my attention.

Now you could be about to ask me if I am in my senses as I have used a Kria KV260 board (a bit over-powered for this task); well, let me justify that: 1\) I like reusing my current stuff (small attempt to minimize the amount of electronics components in my drawers) and 2\) this was to me an introductory project to get familiarized with Kria KV260 system in terms of programmable logic, pmod, Vivado, logic, constraints... I could have stopped at 3% of this project as I had already worked with Zynq US+ architecture before and only needed to load some basic bitstream and PS initialization (processing system) to check everything was up and running, but I get fun doing this :)

<img src="pics/pic1.png" alt="drawing" width="620">

## Usage <a name="Usage"></a>

There are three stages:
1) Board initialization
2) Pause
3) Run generation

There are five buttons that allows the user to interact with the system: CENTER/UP/DOWN/LEFT/RIGHT. For each button, there are up to two kind of events: short and long press (the latter  requires a minimum duration of 2 seconds for the press).

The program starts at Board initialization.
* At this point, the user can select which cells start alive (LED ON) and which start dead (LED OFF). The LED blinking indicates the current position targeted. Buttons UP/DOWN/LEFT/RIGHT (short press) can be used to navigate in the LED matrix CENTER short press can be used to toggle the current cell state.
* Long press in CENTER shall cause the system to switch to Pause stage.

At Pause stage, the program shall go to Run generation if either CENTER is pressed shortly or CONTINUOUS MODE is enabled. If DOWN is pressed (long press), the system shall switch to Board initialization stage, keeping the last array distribution selected by the user when the stage was left the last time.

At Run generation, the program shall calculate and update the matrix with the cell distribution corresponding to a new generation based on the previous state and the rules that define the game. Right after, it shall go to Pause stage (going there and back if CONTINUOUS MODE is enabled).

CONTINUOUS MODE can be toggled by pressing UP (long press) at Pause or Run generation stages.

The game behavior is shown in the diagram below:

<img src="pics/main_fsm.png" alt="drawing" width="620">

## HW/SW Design <a name="Design"></a>

* HW:
    * AMD/Xilinx Kria KV260 (based on K26 SOM and Zynq Ultrascale+ architecture)
    * MAX7219 8x8 LED array
    * 5 buttons + 5 resistors (pull down)
    * 5V power supply + 74hct08n (AND IC to convert KV260's 3.3V pmod outputs to MAX7219 5V inputs) 
* Language: VHDL
* Simulators: GTKWave, Modelsim
* Tools: Vivado, Vitis, VSCode + Teros HDL

<img src="pics/hw_wiring.png" alt="drawing" width="620">

RTL design / top diagram:  
<img src="pics/top_bd.png" alt="drawing" width="620">  
RTL design / button handler diagram:  
<img src="pics/button_handler.png" alt="drawing" width="620">

## Potential updates <a name="pending_tasks"></a>

* Replace IO by HDMI and keyboard, perhaps involving PS
* Randomly generated initial cell distribution

## Contact <a name="Contact"></a>

[![LinkedIn][linkedin-shield]][linkedin-url]


<p align="right">(<a href="#top">back to top</a>)</p>

<!-- README built based on this nice template: https://github.com/othneildrew/Best-README-Template -->

<!-- MARKDOWN LINKS & IMAGES -->

[linkedin-shield]: https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white
[linkedin-url]: https://www.linkedin.com/in/juan-manuel-reina-mu%C3%B1oz-56329b130/