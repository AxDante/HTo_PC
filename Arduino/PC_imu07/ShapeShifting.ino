void secureShape(int form){
  switch(form){
    case 1:
      straight();
      break;
    case 2:
      square();
      break;
    case 3:
      L_4th();
      break;
    case 4:
      L_1st();
      break;
    case 5:
      Z_1_4();
      break;
    case 6:
      plus();
      break;
    case 7:
      S_1_3();
      break;
    default:
      break;
  }
}
void straight()
{
  if (debugMotorActive){
    Herkulex.moveOneAngle(p, -100, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, 98, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, 95, 1000, LED_BLUE); //move motor with 300 speed 
  }
}
void square()
{
  if (debugMotorActive){
    Herkulex.moveOneAngle(p, -101, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, -104, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, 93, 1000, LED_BLUE); //move motor with 300 speed 
  }
}
void L_4th()
{
  if (debugMotorActive){
    Herkulex.moveOneAngle(p, -101, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, 98, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, -99, 1000, LED_BLUE); //move motor with 300 speed 
  }
}
void L_1st()
{
  if (debugMotorActive){
    Herkulex.moveOneAngle(p, 93, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, 98, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, 93, 1000, LED_BLUE); //move motor with 300 speed 
  }
}
void Z_1_4()
{
  if (debugMotorActive){
    Herkulex.moveOneAngle(p, 92, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, 98, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, -98, 1000, LED_BLUE); //move motor with 300 speed 
  }
}
void plus()
{
  if (debugMotorActive){
    Herkulex.moveOneAngle(p, 3, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, -105, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, -98, 1000, LED_BLUE); //move motor with 300 speed 
  }
}
void S_1_3()
{
   if (debugMotorActive){
    Herkulex.moveOneAngle(p, 92, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(q, -10, 1000, LED_BLUE); //move motor with 300 speed 
    Herkulex.moveOneAngle(r, 96, 1000, LED_BLUE); //move motor with 300 speed   
  }
}
