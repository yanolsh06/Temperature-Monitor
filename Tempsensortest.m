clear;
a = arduino('COM3','Nano3','Libraries',{"I2C"});
SensorTempHumidObject = dht20(a);
sensorData = readSensorData(SensorTempHumidObject);
myTemperature = readTemperature(SensorTempHumidObject);
myHumidity = readHumidity(SensorTempHumidObject);

% You can also call it using .annotation:
SensorTempHumidObject.readTemperature
SensorTempHumidObject.readHumidity
SensorTempHumidObject.readSensorData