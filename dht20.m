% Connects to a DHT20 Sensor connected to a hardware object that supports I2C (e.g. an arduino).
% ==================================================================================================
% DHT20 Class I2C Temperature & Humidity Sensor
% By: Eric Prandovszky
% prandov@yorku.ca
% Version 0.7.1
% Oct 31 2024
% Based on the Mathworks HTS221 Temperature and Humidity Sensor Implementation
% To help understand the code, I've tired to comment as as much as I could.
% v0.7.1 Updated to work with r2024+ where device.read() is no longer available and 
% SupportedInterfaces property has been added.
% v0.7 Only tested the MATLAB functions(See Below), not the simulink or coder.
% see below for what methods work and what doesn't or is untested.
% ==================================================================================================
% https://www.mathworks.com/help/matlab/matlab_oop/class-attributes.html
%classdef MyAddon < base class (Inherit your custom add-on class from another class e.g. matlabshared.addon.LibraryBase)
classdef (Sealed) dht20 < matlabshared.sensors.HumiditySensor & matlabshared.sensors.sensorUnit & matlabshared.sensors.TemperatureSensor
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Connecting to the DHT20 (aka AHT20):
%   %Create an arduino object (the default config should have I2C) 
%       serialDevices = serialportlist; 
%   %Usually the arduino's serial port is the last value, otherwise, specify the port
%       a = arduino(serialDevices(end),'Nano3','Libraries',{'I2C'});
%       dht20obj = dht20(a);
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% DHT20 methods:
%                   
% readHumidity(obj)	        Read one sample of relative humidity data from the sensor
% readTemperature(obj)		Read one sample of temperature from sensor
% readSensorData(obj)	    Returns a row vector of Raw Humidity and Temperature Values 
% info(obj)		            Read information related to sensor
% flush(obj)	            Flush the host buffer
%
% *not working yet or doesn't seem to work
% *read	            Read real-time sensor data at a specified rate 
% *release	        Release the sensor object
% *stop             Part of sensorInterface
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% https://www.mathworks.com/help/supportpkg/arduinoio/ref/hts221.html
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Original hts221 methods:
%
% readHumidity()	    Read one sample of relative humidity data from the sensor
% readTemperature()	    Read one sample of temperature from sensor
% read()	            Read real-time sensor data at a specified rate
% release()	            Release the sensor object
% flush()	            Flush the host buffer
% info()	            Read information related to sensor
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% AHT20/DHT20 Humidity and Temperature sensor 
% I2CAddress:   0x38
% I2C Commands:
% _________________________________________________________________________________________________                  
% Initialization Command    0xBE00          Delay 10ms
% Measurement command       0xAC3300        Delay 80ms    Read 7 Bytes
% Soft Reset                0xBA            Delay 20ms
% Get Status                0x71    
% _________________________________________________________________________________________________
% CRC Parameters: *Same as SGP30 
% CRC Init          0xFF
% CRC8 Polynomial   0x31  
%
% Status byte: 
% Bit[7]Busy/Free [6]-[5]-[4]- [3]Calibrated/Uncalibrated [2]-[1]-[0]Unused
%
% Sensor Initialization:
% Sensor power on time: 40ms 
% Get Status Byte
% Check Calibration bit = true
%
% Measurement Response Bytes: 
% [1]Status [2]Humidity [3]Humidity [4]Humidity&Temperature [5]Temperature [6]Temperature [7]Temperature [8]CRC
%
% Relative Humidity Transformation
% RH[%]=(S_rh/2^20)*100%
%
% Temperature Transformation
% T(°C)=(S_t/2^20) *200 - 50
%
% "Activation time of AHT20 should not exceed 10% of the measurement time - it is recommended to measure data every 2 seconds." (4% duty Cycle)
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Properties+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Properties---------------------------------------------------------------------------------------
     properties(SetAccess = protected, GetAccess = public, Hidden)
        %Was unable to change this 
        MinSampleRate = 1;
        MaxSampleRate = 200;
    end
% Properties---------------------------------------------------------------------------------------
    properties(Nontunable, Hidden)
        DoF = [1;1];
    end
% Properties---------------------------------------------------------------------------------------  
    properties(Access = protected, Constant)
        HumidityDataRegister = 0x71; %AHT20 has no Humidity register
        TemperatureDataRegister = 0x71; %AHT20 has no Temperature register
        StatusRegister = 0x71; %AHT20 Status
        DeviceID = 0x38; %AHT20 I2C Address
        %ODRParametersHumidity = [1,7,12.5]; %HTS221 Frequency in Hz 
        ODRParametersHumidity = [0.1667,0.1,0.5,1.25]; % AHT20 60s, 10s, 2s(recommended), 0.8s(maximum suggested)
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = protected, Constant)
        SupportedInterfaces = 'I2C';
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = {?matlabshared.sensors.coder.matlab.sensorInterface, ?matlabshared.sensors.sensorInterface}, Constant)
        I2CAddressList = 0x38;  %AHT20
        LoggingEnabled = false;
    end
% Properties---------------------------------------------------------------------------------------
    properties(Access = protected,Nontunable)
        HumidityResolution=1/256;
        TemperatureResolution=1/64;
        OutputDataRate;
        IsActiveHumidity=true;
        IsActiveTemperature=true;
    end
% Properties---------------------------------------------------------------------------------------
    properties(Hidden, Constant)
        WHO_AM_I = 0x0F; % Unsupported in AHT20
        BytesToRead = 7; % AHT20 Full sensor read is 7 Bytes
        BytesToReadForTemperature = 7;
        BytesToReadForCalibration = 7;
        crc8Polynomial = 0x31;
        crc8Init = 0xFF;
    end
% Properties---------------------------------------------------------------------------------------
    properties (Access = protected)
    end
% Methods------------------------------------------------------------------------------------------
    % https://www.mathworks.com/help/matlab/matlab_oop/how-to-use-methods.html
    % https://www.mathworks.com/help/matlab/matlab_oop/method-attributes.html
%--------------------------------------------------------------------------------------------------
% Public methods — Unrestricted access    
% Constructor(Public)-------------------------------------------------------------------
    methods
        function obj = dht20(varargin)
            obj@matlabshared.sensors.sensorUnit(varargin{:})
            if ~obj.isSimulink                  %is not simulink
                % Code generation does not support try-catch block. So init
                % function call is made separately in both codegen and IO
                % context.
                if ~coder.target('MATLAB')      %is not simulink or coder, then what??
                    names = {'Bus','OutputFormat','TimeFormat','SamplesPerRead', 'SampleRate','ReadMode'};
                    defaults = {[],'timetable','datetime',10, 10,'latest'};
                    p = matlabshared.sensors.internal.NameValueParserInternal(names, defaults ,false);
                    p.parse(varargin{2:end});
                    obj.init(varargin{:});
                else            
                    try                         %is Matlab
                       %names = {'Bus','OutputFormat','TimeFormat','SamplesPerRead', 'SampleRate','ReadMode'};
                       %defaults = {[],'timetable','datetime',10, 12.5,'latest'};
                        names = {'Bus','I2CAddress','SampleRate','LoggingEnabled'};
                        defaults = {[],'0x38',1,false};
                        p = matlabshared.sensors.internal.NameValueParserInternal(names, defaults ,false);
                        p.parse(varargin{2:end});   %any user parameters are appaneded
                        obj.init(varargin{:});
                    catch ME
                        throwAsCaller(ME);
                    end
                end
            else                                %is Simulink
                names =     {'Bus','IsActiveHumidity','IsActiveTemperature','OutputDataRate'};
                defaults =    {0,true,true,1};
                p = matlabshared.sensors.internal.NameValueParserInternal(names, defaults ,false);
                p.parse(varargin{2:end});
                bus =  p.parameterValue('Bus');
                obj.init(varargin{1},'Bus',bus);
                obj.IsActiveHumidity=p.parameterValue('IsActiveHumidity');
                obj.IsActiveTemperature=p.parameterValue('IsActiveTemperature');
                if obj.IsActiveHumidity || obj.IsActiveTemperature
                    obj.OutputDataRate =  p.parameterValue('OutputDataRate');
                end
            end
        end
%Public method-------------------------------------------------------------------------------------
        function set.OutputDataRate(obj, value)
           %AHT20 doesn't have a data-rate config register
            obj.OutputDataRate = value;
        end
% Public method------------------------------------------------------------------% Public method to read data  
        function rawSensorData = readSensorData(obj)
        % Returns a row vector of Raw Humidity and Temperature  Values 
        obj.logme(dbstack,'Public'); 
        sensorData = readSensorDataImpl(obj);
        rawSensorData(1) = bitshift(swapbytes(typecast(uint8(sensorData(1:4)),'uint32')),-12);  % See convertHumidityData()
        rawSensorData(2) = bitshift(bitshift(swapbytes(typecast(uint8(sensorData(2:5)),'uint32')),12),-12); % See convertTemperatureData()
        end    
    end%of Public Methods
% Protected methods+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% Access from methods in class or subclasses   
    methods(Access = protected)
% Protected method---------------------------------------------------------------% defined in matlabshared.sensors.sensorUnit
        function initDeviceImpl(obj)
            if coder.target('MATLAB')
                %deviceid_value = readRegister(obj.Device, obj.WHO_AM_I);
                deviceid_value = obj.DeviceID;
                if(deviceid_value ~= obj.DeviceID)
                    matlabshared.sensors.internal.localizedWarning('matlab_sensors:general:invalidDeviceID','DHT20',num2str(obj.DeviceID));
                end
            end
            dht20.logme(dbstack,'Oh hi Mark');
        end
%Protected method---------------------------------------------------------------% defined in matlabshared.sensors.sensorUnit         
        function initSensorImpl(obj)
            % Sensor Initialization:
            java.lang.Thread.sleep(40); %Prevent a read attempt within 40ms of powering on.
            % Get Status Command: 0x71  Delay: none
            statusByte = uint8(readRegister(obj.Device, obj.StatusRegister));
            % Normal Status: 0x1C  00011100
            if obj.LoggingEnabled
            statusBits = dec2bin(statusByte);
            fprintf('Status: %u: %s\n',statusByte, statusBits);
            end
            
            % Check Calibration bit: Bit[3] = true
            if bitget(statusByte,4) % Rmember: bit[3] is actually bit[4] to matlab
            % If status bit is TRUE, sensor is Ready
                obj.logme(dbstack,'Sensor Ready');
            else 
            % If status bit is FALSE, send the initialization command 
            % Initialization command: 0xBE00  Delay: 10ms
                command = [0xBE 0x00]; 
                delay = 10;
                write(obj.Device,command); %write(I2C_Address, Bytes, Precision)
                java.lang.Thread.sleep(delay);
                statusByte = uint8(readRegister(obj.Device, obj.StatusRegister));
                statusBits = dec2bin(statusByte);
                if bitget(statusByte,4)
                    if obj.LoggingEnabled
                    fprintf('Status: %u: %s\n',statusByte, statusBits);
                    fprintf('Sensor Ready\n');
                    end
                else
                fprintf('Sensor Error\n');
                end
                % ! If this still fails, should throw an error
            end
        end
%Protected method----------------------------------------------------------------------------------
% Called from matlabshared.sensors.sensorUnit  recordStreamingRequest(obj) & stepImpl(obj)
        function [data,status,timestamp]  = readSensorDataImpl(obj)
            obj.logme(dbstack,'Read Data');
            % Measurement command       0xAC3300   Delay 80ms    Read 7 Bytes
            command = [0xAC 0x33 0x00]; 
            delay = 80;
            readSizeBytes = 7;
            write(obj.Device,command); %write(I2C_Address, Bytes, Precision)
            java.lang.Thread.sleep(delay); % millisecond base unlike pause(seconds) 
            %OLD statusDataCrc = read(obj.Device,readSizeBytes,"uint8");
            %NEW I2CsensorDevice.readRegister(obj, registerAddress, numBytes, precision)
            statusDataCrc = readRegister(obj.Device,0x00,readSizeBytes,"uint8");
            statusByte = statusDataCrc(1);
            statusData = statusDataCrc(1:end-1);
            data = statusDataCrc(2:end-1);
            crcByte = statusDataCrc(end);
            crcCalc = generateCrc(obj,statusData);
            if obj.LoggingEnabled
                if bitget(statusDataCrc(1),4);fprintf('\tCAL OK\n');end
                if bitget(statusDataCrc(1),8);fprintf('\tSensor Busy\n');else;fprintf('\tReading Complete!\n');end
                fprintf('\tI2C Packet: %X %X %X %X %X %X %X\n',statusDataCrc);
                fprintf('\tI2C Status: %X \n',statusByte);
                fprintf('\tI2C Data  :\t   %X %X %X %X %X \n',data);
                fprintf('\tI2C CRC   :\t\t\t\t\t  %X \n',crcByte);
                fprintf('\tCRC Calc  :\t\t\t\t\t  %X \n',crcByte);
                if crcByte == crcCalc;fprintf('\tData Verification: CRC PASS! \n\t[CRC Calculation = I2C Packet CRC]\n')
                else;fprintf('\tData Verification: CRC Calc != I2CpacketCRC,  crc FAIL! \n'); end
            end
            status = 0; %Status can take 3 values namely -1 sensor not used, 0 data available, 1 data not yet available
            timestamp = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss.SSS');
        end
%Protected method---------------------------------------------------------------Access by calling readHumidity(obj) handle from HumiditySensor.m      
        function [data,status,timestamp]  = readHumidityImpl(obj)
            obj.logme(dbstack,'Humidity');
            [data,status,timestamp]  = readSensorDataImpl(obj);
            data = convertHumidityData(obj,data);
%             status = 0;
%             timestamp = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss.SSS');
        end
%Protected method----------------------------------------------------------------------------------
% Called from readTemperature(obj) Handle from TemperatureSensor.m      
        function [data,status,timestamp]  = readTemperatureImpl(obj)
            obj.logme(dbstack,'Temperature');
            [data,status,timestamp]  = readSensorDataImpl(obj);
            data = convertTemperatureData(obj, data);
        end
%Protected method----------------------------------------------------------------------------------
% Called from matlabshared.sensors.sensorUnit  readLatestFrame(obj)  
        function data = convertSensorDataImpl(obj, data)
            data=[convertHumidityData(obj, data(1:obj.BytesToRead)) convertTemperatureData(obj, data(obj.BytesToRead+1:obj.BytesToRead+obj.BytesToReadForTemperature))];
        end
%Protected method----------------------------------------------------------------------------------
% Called from matlabshared.sensors.sensorBase.m  set.SampleRate(obj, value) & setPropertiesWithStreamingInfoHook(obj,props)
        function setODRImpl(obj)
            % used only for MATLAB
            outputDataRate = obj.ODRParametersHumidity(obj.ODRParametersHumidity<=obj.SampleRate);
            obj.OutputDataRate = outputDataRate(end);
        end
%Protected method----------------------------------------------------------------------------------
% Called from matlabshared.sensors.sensorInterface.p
        function s = infoImpl(obj)
            s = struct('OutputDataRate',obj.OutputDataRate);
        end
%Protected method---------------------------------------------------------------------------------- 
% Called from matlabshared.sensors.sensorUnit.m  [constructor] sensorUnit(varargin) 
        function names = getMeasurementDataNames(obj)
            names = [obj.HumidityDataName, obj.TemperatureDataName];
        end
    end
%Hidden methods++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    methods(Hidden = true)
%Hidden method-------------------------------------------------------------------------------------
        function [status,timestamp] = readStatus(obj)
            %Status can take 3 values namely -1,0,1
            %-1 represents the sensor is not used
            %0 represents  new data is available
            %1 represents  new data is not yet available
            timestamp = [];
            status=[-1,-1];
            if obj.IsActiveHumidity
                                        %readRegisterData(obj, DataRegister, numBytes, precision)
                [temp,~,timestamp] = obj.readRegisterData(obj.StatusRegister, 1, 'uint8');
                statusValues = bitget(uint8(temp),8); %MSB of Status is Busy[1]/Free[0] Flag
                if(isequal(statusValues,1))
                    status(1)=0; %[0]Free
                else
                    status(1)=1; %[1]Busy
                end
            end
            if obj.IsActiveTemperature
                [temp,~,timestamp] = obj.readRegisterData(obj.StatusRegister, 1, 'uint8');
                statusValues = bitget(uint8(temp),8); %MSB of Status is Busy[1]/Free[0] Flag
                if(isequal(statusValues,1))
                    status(2)=0; %[0]Free
                else
                    status(2)=1; %[1]Busy
                end
            end
        end
    end
% Private Methods++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++    
    methods(Access = private)
% Private Method-----------------------------------------------------------------------------------
        function relativeHumidity = convertHumidityData(obj,sensorData)
            obj.logme(dbstack,'Convert');
            %Bytes [1]Status [2]Humidity [3]Humidity [4]Humidity&Temperature [5]Temperature [6]Temperature [7]Temperature [8]CRC
            humidityAndTemperature = swapbytes(typecast(uint8(sensorData(1:4)),'uint32')); % Copy the first 4-bytes of data and join into a 32-bit unsigned integer
            humidityBits = bitshift(humidityAndTemperature,-12);       % Humidity data is the FIRST 20-bits, remaining 12-bits is the temperature. Shift those out.
            
            %relativeHumidity = single(humidityBits)/2^20*100;   % Relative Humidity in percent
            relativeHumidity = double(humidityBits)/10485.76;   % Relative Humidity in percent (dataBits/2^20*100 = dataBits/10485.76)
        end
% Private Method-----------------------------------------------------------------------------------
        function temperature = convertTemperatureData(obj, sensorData)
            obj.logme(dbstack,'Convert');
            %Bytes [1]Status [2]Humidity [3]Humidity [4]Humidity&Temperature [5]Temperature [6]Temperature [7]Temperature [8]CRC
            humidityAndTemperature = swapbytes(typecast(uint8(sensorData(2:5)),'uint32')); % Copy the last 4-bytes of data and join into a 32-bit unsigned integer
            temperatureBits = bitshift(bitshift(humidityAndTemperature,12),-12);       % Temperature data is the LAST 20-bits, perceeding 12-bits is the Humidity. Shake those out.
            %temperatureBits = bitand(humidAndTemperature,0x000FFFFF);       % Temperature data is the LAST 20-bits, perceeding 12-bits is the Humidity. Mask them out.
 
            temperature = double(temperatureBits)/2^20*200-50;   % Temperature in °C   2^20*200-50 = 5242.88-50
            %temperature = double(temperatureBits)/5242.88-50;   % Temperature in °C   2^20*200-50 = 5242.88-50
        end
% Private Method-----------------------------------------------------------------------------------
        function resetRegisters(obj)
            %Enabling Soft Reset of device
            % Soft Reset                0xBA        1011 1010       Delay 20ms
            obj.logme(dbstack,'Soft Reset');
            command = 0xBA; 
            delay = 20;
            write(obj.Device,command); %write(I2C_Address, Bytes, Precision)
            java.lang.Thread.sleep(delay);
        end
% Private Method-----------------------------------------------------------------------------------
function crcOut = generateCrc(obj,data)
        % https://www.mathworks.com/help/matlab/matlab_prog/perform-cyclic-redundancy-check.html
        % Created based on SGP30.JAVA GenerateCRC method:
        crc = obj.crc8Init;                %DHT20  crc8Init is 0xFF
        polynomial = obj.crc8Polynomial;   %DHT20  crc8Polynomial is 0x31
        for k= 1:length(data)
            bt = uint8(data(k));
            crc = bitxor(crc,bt);
            for  i = 1:8
                test = bitand(crc,0x80);
                if test ~= 0
                    crc = bitxor(bitshift(crc,1),polynomial); 
                else
                    crc = bitshift(crc,1);
                end
            end
        end
        crcOut = bitand(crc,0xFF); %makes sure CRC is a maximum of 1 byte, might typecast it too??
        % SGP30 Datasheet Example CRC: 0xBEEF = 0x92
    end
    end%of Private Methods
%--------------------------------------------------------------------------------------------------
    methods(Static,Hidden)
        %Static Method------dht20.m  Logging function. 
        function logme(lineNumStruct,messageToLog)
            % Setup as a static function, to call: 
            % Use   dht20.logme(dbstack,'message to log') 
            % Or    obj.logme(dbstack,'message to log');
            if dht20.LoggingEnabled
                %mFile = lineNumStruct.('file'); 
                mLine = lineNumStruct.('line');
                mMethod = lineNumStruct.('name');
                fprintf('log:\tLine#%i\tMethod:%s  \t%s\n', mLine(1), mMethod , messageToLog);
            end
        end%of logme
    end
end%of dht20 class
%==================================================================================================