function state = BONUSPROJECTYAN
%function is the state for the machine code
% Initialize Arduino and DHT20 sensor
a = arduino('COM3', 'Nano3', 'Libraries', {'I2C'});
SensorTempHumidObject = dht20(a);

% Define pins for LED and buzzers
ledPin = 'D4';  % LED pin
buzzerPin = 'D5';  % Buzzer pin

% Configure pins as output
configurePin(a, ledPin, 'DigitalOutput');
configurePin(a, buzzerPin, 'DigitalOutput');

% Total monitoring time in seconds (optional limit, or use Ctrl+C to stop)
totalTime = 300;  % 5 minutes

% Tracks the start time
startTime = tic;

% Creates a figure with two subplots for Temperature and Humidity
figure;

% Temperature Plot (subplot 1)
subplot(2, 1, 1);  % Two rows, one column, first plot
hTemp = animatedline('Color', 'r', 'LineWidth', 2);  % Animated line for temperature
axTemp = gca;
axTemp.YGrid = 'on';                  % Enables the Y-axis grid
axTemp.YLim = [0, 50];                % Temperature range (adjustable)
title('Real-Time Temperature vs. Time');  
xlabel('Time [s]');
ylabel('Temperature (°C)');

% Humidity Plot (subplot 2)
subplot(2, 1, 2);  % Two rows, one column, second plot
hHumid = animatedline('Color', 'b', 'LineWidth', 2);  % Animated line for humidity
axHumid = gca;
axHumid.YGrid = 'on';                 % Enables the Y-axis grid
axHumid.YLim = [0, 100];              % Humidity range (0-100%)
title('Real-Time Humidity vs. Time');  
xlabel('Time [s]');
ylabel('Humidity (%)');

% Initializes empty arrays to store text handles
tempTextHandles = [];
humidTextHandles = [];

% Define temperature thresholds for state machine
low_threshold = 20;  % Low temperature threshold (°C)
high_threshold = 25; % High temperature threshold (°C)

% Monitoring Loop
while toc(startTime) < totalTime
    % Reads the temperature and humidity data from the DHT20 sensor
    temp = readTemperature(SensorTempHumidObject);
    humid = readHumidity(SensorTempHumidObject);

    % Gets the elapsed time in seconds
    elapsedTime = toc(startTime);

    % State Machine Logic based on Temperature
    if temp < low_threshold
        state = 'Low Temperature (Heating Mode)';
        disp('Temperature is low. Please activate your heater...');
        
        % Turn on buzzer and led 
        writeDigitalPin(a, buzzerPin, 1);
        writeDigitalPin(a, ledPin, 1);
    elseif temp >= low_threshold && temp <= high_threshold
        state = 'Ideal Temperature (Comfort Zone)';
        disp('Temperature is within the comfort range. No action needed.');
        
        % Turn off all indicators
        writeDigitalPin(a, buzzerPin, 0);
        writeDigitalPin(a, ledPin, 0);
    elseif temp > high_threshold
        state = 'High Temperature (Cooling Mode)';
        disp('Temperature is high. Please activate your cooling system...');
        
        % Turn on buzzer and LED
        writeDigitalPin(a, buzzerPin, 1);
        writeDigitalPin(a, ledPin, 1);
    else
        state = 'ALERT SOMETHING WENT WRONG';
        clc;  % Clears command window
        disp(state);
    end

    % Updates Temperature Plot
    subplot(2, 1, 1);  % Focuses on temperature plot
    addpoints(hTemp, elapsedTime, temp);  % Adds temperature data point
    if ~isempty(tempTextHandles)
        delete(tempTextHandles);  % Deletes the previous text objects
    end
    tempTextHandles = text(elapsedTime, temp, sprintf('%.2f°C', temp), 'Color', 'r', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
    axTemp.YTick = 0:5:50;  % Customizes the Y ticks
    drawnow;

    % Updates Humidity Plot
    subplot(2, 1, 2);  % Focuses on humidity plot
    addpoints(hHumid, elapsedTime, humid);  % Adds humidity data point
    if ~isempty(humidTextHandles)
        delete(humidTextHandles);  % Deletes the previous text objects
    end
    humidTextHandles = text(elapsedTime, humid, sprintf('%.2f%%', humid), 'Color', 'b', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
    drawnow;
end

% Clean up and reset pins
writeDigitalPin(a, buzzerLowPin, 0);
writeDigitalPin(a, buzzerHighPin, 0);
writeDigitalPin(a, ledPin, 0);
clear a;
end
