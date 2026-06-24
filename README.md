# Temperature-Monitor

An automated environmental tracking architecture combining an Arduino board with a DHT20 sensor to monitor real-time temperature/humidity boundaries and map live data visualization trends.

[Read Full Project Documentation](./Water%20Project%20Documentation.pdf)
---

## Hardware Setup & Prototyping
![image alt](https://github.com/yanolsh06/Temperature-Monitor/blob/4a01974ec263bac2288f5ae131b2afd1fd383310/C07567F2-7446-432E-ACF0-1A330A952761.png)

---

## System Architecture & Tech Stack
* **Microcontroller Platform:** Arduino Grove Nano Board 
* **Core Languages & APIs:** MATLAB Scripting, I2C Communication Protocol 
* **Hardware Interfacing:** DHT20 Temperature & Humidity Sensor, Status LEDs, Audible Buzzer Alarm Matrix 
* **Mathematical Operations:** Raw 20-bit bit-shifting conversions to normalize raw ADC counts into standardized percentage and Celsius outputs 

---

## How It Works (Finite State Machine)
The monitoring script runs a continuous loop that polls physical sensor data over I2C every 2 seconds to transition dynamically through climate control states:
1. **Low Temperature State (< 20°C):** Prompts heater activation and triggers warning indicators (LED and buzzer).
2. **Ideal Comfort State (20°C – 25°C):** Confirms neutral state; deactivates all safety peripherals.
3. **High Temperature State (> 25°C):** Prompts cooling system activation and triggers warning indicators (LED and buzzer).

---

## Live Data Visualization
* **Dynamic Subplot Rendering:** Utilizing custom animated tracking line structures (`hTemp` and `hHumid`) to display live indoor/outdoor telemetry changes.
* **Handle Management Overhead:** Implemented dynamic text handle arrays that continuously clear previous metrics inside the loop iteration to prevent image lag and maintain a clean figure output.
* **Telemetry Bounds:** Formatted to plot temperature scales from 0°C to 50°C and relative humidity levels from 0% to 100% against time on the horizontal axis.
