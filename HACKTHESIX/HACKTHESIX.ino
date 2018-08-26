//Import appropriate libraries
#include <WiFi.h>
#include <WiFiUdp.h>
#include <WiFiClient.h>
#include <WiFiServer.h>
#include <PubSubClient.h>
#include <NewPing.h>
//#include <Servo.h>
//#include <VarSpeedServo.h>
#include <ESP32_Servo.h>

//Define constants
#define SONAR_NUM 2
#define MAX_DISTANCE 50

//Define min function
#define min(a,b) ((a)<(b)?(a):(b))

//Device Specific Definitions for IBM Cloud
#define ORG "bquydw"
#define DEVICE_TYPE "ESP32"
#define DEVICE_ID "hackthesix"
#define TOKEN "qu+yHAug0C0X-7xwaL"

//Wifi Network specifics
const char* ssid = "TankLDW"; //your WiFi Name
const char* password = "tancred1234";  //Your Wifi Password

//Pin definitions
int servoPanPin = 18;
int servoTiltPin = 19;
int motor1EN = 12;
int motor1A = 4;
int motor1B = 5;
int motor2EN = 13;
int motor2A = 15;
int motor2B = 14;

int echoFront = 26;
int echoBack = 22;
int trigFront = 27;
int trigBack = 23;

//Servos
Servo servoPan;
Servo servoTilt;
int panPos = 0;
int tiltPos = 0;

//DC motors
int channelMotor = 0;

//Sonars
NewPing sonar[SONAR_NUM] = {   // Sensor object array.
  NewPing(trigFront, echoFront, MAX_DISTANCE), // Each sensor's trigger pin, echo pin, and max distance to ping. 
  NewPing(trigBack, echoBack, MAX_DISTANCE), 
};

int sonarFrontDist = 0;
int sonarBackDist = 0;

//Timer variables
long currentMillis = 0;
long lastPubMillis = 0;

//Serial command
char cmd = 0;

//Set up basics for IBM server
char server[] = ORG ".messaging.internetofthings.ibmcloud.com";
char pubtopic[] = "iot-2/evt/status/fmt/json";
char subtopic[] = "iot-2/cmd/+/fmt/String";
char authMethod[] = "use-token-auth";
char token[] = TOKEN;
char clientId[] = "d:" ORG ":" DEVICE_TYPE ":" DEVICE_ID;

/* HELPER FUNCTIONS */
void servoMove(Servo servo, int cur, int angle, int slow = 20) {
  int endPos = angle;
  int startPos = cur;
  int pos = 0;

  if (startPos < endPos) {
    for (pos = startPos; pos <= endPos; pos += 1) { // goes from 0 degrees to 180 degrees
      // in steps of 1 degree
      servo.write(pos);              // tell servo to go to position in variable 'pos'
      delay(slow);                       // waits 15ms for the servo to reach the position
    }
  }
  else {
    for (pos = startPos; pos >= endPos; pos -= 1) { // goes from 0 degrees to 180 degrees
      // in steps of 1 degree
      servo.write(pos);              // tell servo to go to position in variable 'pos'
      delay(slow);                       // waits 15ms for the servo to reach the position
    }
  }
}

void WiFiConnect(const char* ssid, const char* password) {
  //Set up network
  Serial.print("Connecting to "); Serial.print(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.print("WiFi connected, IP address: "); Serial.println(WiFi.localIP());
}

/* MQTT CORE FUNCTIONS */
//Set up WiFi client
WiFiClient wifiClient;
PubSubClient client(server, 1883, callback, wifiClient);

void mqttConnect(char* clientId, char* authMethod, char* token) {
    while (!client.connect(clientId, authMethod, token)) {
      Serial.print(".");
      delay(200);
    }  
    
    Serial.println();
    
    if (!client.subscribe(subtopic)) {
      Serial.println("Subscription failed!"); 
    }
    else {
       Serial.print("Subscribed to:");
       Serial.println(subtopic);
    }
}

void mqttPublish(char* topic, char* payload) {
  Serial.print("Publishing: ");
  Serial.println(payload);

  if (client.publish(pubtopic, payload)) {
    Serial.println("Publish ok");
  }
  else {
    Serial.println("Publish failed");
  }
}

void callback(char* topic, byte* payload, unsigned int length)
{
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  for (int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
  cmd = (char)payload[0];

  //Tilt up
  if (cmd == 'i') {
    while (cmd == 'i'){
      if (tiltPos >= 0 and tiltPos < 50) {
        servoMove(servoTilt, tiltPos, tiltPos+1, 50);   
        tiltPos = tiltPos + 1;
      }    
      cmd = (char)payload[0];
      client.loop();
      delay(10);  
    }
  }
  
  //Tilt down
  if (cmd == 'k') {
    while (cmd == 'k') {
      if (tiltPos > 0 and tiltPos <= 50) {
        servoMove(servoTilt, tiltPos, tiltPos-1, 50);
        tiltPos = tiltPos - 1;
      }
      cmd = (char)payload[0];
      client.loop();
      delay(10);
    }
  }

  //Pan right
  if (cmd == 'l') {
    while (cmd == 'l') {
      servoMove(servoPan, panPos, panPos+1, 25);
      if (panPos > 0 and panPos <= 180) {
        panPos = panPos - 1;
      }      
      cmd = (char)payload[0];
      client.loop();
      delay(10);        
    }
  }

  //Pan left
  if (cmd == 'j') {
    while (cmd == 'j') {
      servoMove(servoPan, panPos, panPos-1, 25);
      if (panPos >= 0 and panPos < 180) {
        panPos = panPos + 1;
      }      
      cmd = (char)payload[0];
      client.loop();
      delay(10);        
    }
  }
  
  //Move up
  if (cmd == 'w') {
    digitalWrite(motor1A, HIGH);
    digitalWrite(motor1B, LOW);
    digitalWrite(motor2A, HIGH);
    digitalWrite(motor2B, LOW);
    digitalWrite(motor1EN, HIGH);
    digitalWrite(motor2EN, HIGH);
//    ledcWrite(channelMotor, 50);
//    delay(500);
//    digitalWrite(motor1EN, LOW);
//    digitalWrite(motor2EN, LOW);
//    ledcWrite(channelMotor, 0);
    while (cmd == 'w') {
      cmd = (char)payload[0];
      sonarFrontDist = sonar[0].ping_cm();
      Serial.println(sonarFrontDist);
      if(sonarFrontDist > 7 or sonarFrontDist == 0) {
        digitalWrite(motor1EN, LOW);
        digitalWrite(motor2EN, LOW);  
      }
      client.loop();
      delay(10);
    }
    digitalWrite(motor1EN, LOW);
    digitalWrite(motor2EN, LOW);   
  }

  //Move down
  if (cmd == 's') {
    digitalWrite(motor1A, LOW);
    digitalWrite(motor1B, HIGH);
    digitalWrite(motor2A, LOW);
    digitalWrite(motor2B, HIGH);
    digitalWrite(motor1EN, HIGH);
    digitalWrite(motor2EN, HIGH);
//    ledcWrite(channelMotor, 50);
//    delay(500);
//    digitalWrite(motor1EN, LOW);
//    digitalWrite(motor2EN, LOW);
//    ledcWrite(channelMotor, 0);
    while (cmd == 's') {
      cmd = (char)payload[0];
      sonarBackDist = sonar[1].ping_cm();
      Serial.println(sonarBackDist);
      if(sonarBackDist < 10 and sonarBackDist != 0) {
        digitalWrite(motor1EN, LOW);
        digitalWrite(motor2EN, LOW);  
      }
      client.loop();
      delay(50);
    }
    digitalWrite(motor1EN, LOW);
    digitalWrite(motor2EN, LOW);   
  }

  //Move right
  if (cmd == 'd') {
    digitalWrite(motor1A, LOW);
    digitalWrite(motor1B, HIGH);
    digitalWrite(motor2A, HIGH);
    digitalWrite(motor2B, LOW);
    digitalWrite(motor1EN, HIGH);
    digitalWrite(motor2EN, HIGH);
//    ledcWrite(channelMotor, 50);
//    delay(500);
//    digitalWrite(motor1EN, LOW);
//    digitalWrite(motor2EN, LOW);
//    ledcWrite(channelMotor, 0);
    while (cmd == 'd') {
      cmd = (char)payload[0];
      client.loop();
      delay(10);
    }
    digitalWrite(motor1EN, LOW);
    digitalWrite(motor2EN, LOW); 
  }  

  //Move left
  if (cmd == 'a') {
    digitalWrite(motor1A, HIGH);
    digitalWrite(motor1B, LOW);
    digitalWrite(motor2A, LOW);
    digitalWrite(motor2B, HIGH);
    digitalWrite(motor1EN, HIGH);
    digitalWrite(motor2EN, HIGH);
//    ledcWrite(channelMotor, 200);
//    delay(500);
//    digitalWrite(motor1EN, LOW);
//    digitalWrite(motor2EN, LOW);
//    ledcWrite(channelMotor, 0);
    while (cmd == 'a') {
      cmd = (char)payload[0];
      client.loop();
      delay(10);
    }
//    ledcWrite(channelMotor, 0);
    digitalWrite(motor1EN, LOW);
    digitalWrite(motor2EN, LOW);      
  }    
}

/* START OF MAIN PROGRAM */
void setup() {
  Serial.begin(115200);
  Serial.println();
  delay(10);

  WiFiConnect(ssid, password);
   
  //Attach servos  
  servoPan.attach(servoPanPin, 500, 2500);
  servoTilt.attach(servoTiltPin, 500, 2500);

  panPos = 90;
  tiltPos = 30;
  
  //Set up I/O
  pinMode(motor1A, OUTPUT);
  pinMode(motor1B, OUTPUT);
  pinMode(motor2A, OUTPUT);
  pinMode(motor2B, OUTPUT);
  pinMode(motor1EN, OUTPUT);
  pinMode(motor2EN, OUTPUT);

  //For PWM
//  ledcSetup(channelMotor, 500, 8);
//  ledcAttachPin(motor1EN, channelMotor);
//  ledcAttachPin(motor2EN, channelMotor);
}

void loop() {
  //IBM cloud connection as a client
  if (!client.connected()) {
    Serial.print("Connecting client to ");
    Serial.println(server);
    mqttConnect(clientId, authMethod, token);
  }

  //Start of time cycle
  currentMillis = millis();

  //if (Serial.available()) {
  //  cmd = Serial.read();
  // }
  
  //Updating payload to server
  if (currentMillis - lastPubMillis >= 5000) {
    char* payload = "OK";
    mqttPublish(pubtopic, payload);
    Serial.println(panPos);
    Serial.println(tiltPos);
    lastPubMillis = currentMillis;
  }
 
  client.loop();
}


