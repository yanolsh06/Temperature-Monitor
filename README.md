# Temperature-Monitor

An automated environmental tracking architecture combining an Arduino board with a DHT20 sensor to monitor real-time temperature/humidity boundaries and map live data visualization trends.

---

## Hardware Setup & Prototyping
![image alt](https://github.com/yanolsh06/Temperature-Monitor/blob/4a01974ec263bac2288f5ae131b2afd1fd383310/C07567F2-7446-432E-ACF0-1A330A952761.png)

---

## System Architecture & Tech Stack
* [cite_start]**Microcontroller Platform:** Arduino Grove Nano Board [cite: 7, 49]
* [cite_start]**Core Languages & APIs:** MATLAB Scripting, I2C Communication Protocol [cite: 20, 52]
* [cite_start]**Hardware Interfacing:** DHT20 Temperature & Humidity Sensor, Status LEDs, Audible Buzzer Alarm Matrix [cite: 8, 9, 10, 15]
* [cite_start]**Mathematical Operations:** Raw 20-bit bit-shifting conversions to normalize raw ADC counts into standardized percentage and Celsius outputs [cite: 52, 53, 54, 55]

---

## How It Works (Finite State Machine)
[cite_start]The monitoring script runs a continuous loop that polls physical sensor data over I2C every 2 seconds to transition dynamically through climate control states[cite: 50, 52, 101]:
1. [cite_start]**Low Temperature State (< 20°C):** Prompts heater activation and triggers warning indicators (LED and buzzer)[cite: 102, 103].
2. [cite_start]**Ideal Comfort State (20°C – 25°C):** Confirms neutral state; deactivates all safety peripherals[cite: 104].
3. [cite_start]**High Temperature State (> 25°C):** Prompts cooling system activation and triggers warning indicators (LED and buzzer)[cite: 105].

---

## Live Data Visualization
* [cite_start]**Dynamic Subplot Rendering:** Utilizing custom animated tracking line structures (`hTemp` and `hHumid`) to display live indoor/outdoor telemetry changes[cite: 100, 107].
* [cite_start]**Handle Management Overhead:** Implemented dynamic text handle arrays that continuously clear previous metrics inside the loop iteration to prevent image lag and maintain a clean figure output[cite: 108, 194, 196].
* [cite_start]**Telemetry Bounds:** Formatted to plot temperature scales from 0°C to 50°C and relative humidity levels from 0% to 100% against time on the horizontal axis[cite: 48, 51].
