//SLAVE CONTROLLER!!
//Controls solar panel heat collection system
//Judas Gutenberg
//part of SOLAR CONTROLLER III:
//February 20, 2011: added this slave arduino for more analog inputs, an LCD display, and a bunch of EEPROM
//June 23, 2011:  added a menu system developed since late April. 
//menu system happens entirely on this Slave (using the LCD and an IR remote), 
//and then sends commands to Master in the same format as commands to Master
//sent via the serial terminal (previously, the only way to reconfigure the controller).
//requires Ken Shirriff's IRremote, LiquidCrystal, Wire, and EEPROM libraries
 
#include <LiquidCrystal.h>
#include <Wire.h>    
#include <EEPROM.h>
#include <IRremote.h>
#include <avr/wdt.h>
#define SLAVE  19   
#define BAUD_RATE 19200 
#define COMMANDTOMASTERMODE 0 
int RECV_PIN = 2; 
//COMMANDTOMASTERMODE: 
//0= send menu commands to master via Wire library.  
//1= just print them out on this slave's serial terminal (for debugging)

 
char str_abandoned[] =" abandoned.";
char str_saved[] =" saved.";
char str_changes[] =" Changes";
char str_degF[] =" deg. F";
char str_deciseconds[] =" deciseconds";

byte value; 
int temp1;
int temp2;
int temp3;
int temp4;

unsigned long timeOfLastFuelCheck=0;

int lasteepromread;
unsigned int heartbeat=0;
byte lastpinread;
char charblock[20][8];
unsigned int xpos[8];
unsigned int ypos[8];
byte extrabyte[3];

byte outcount=0;
byte low, high;
byte commandbyte=0;
byte readvalue;
unsigned int address;
 
byte * deliverable;
bool nonlcdmode=false;
bool booted=false;
//slave packet is the data regularly sent back to the master via i2c
byte slave_packet[32]; 
#if COMMANDTOMASTERMODE == 0
byte  commandpacket[18];
#else
char  commandpacket[18];
#endif
LiquidCrystal lcd(7, 8, 9, 10, 11, 12);

IRrecv irrecv(RECV_PIN);
decode_results results;
long IRresval;
byte IRlow;
byte IRhigh;
byte ir_packet[18]; 
int integers[12]={255,32895,16575,49215,8415,41055,24735,57375,4335,36975,31371343,31357063};//last two are colon and dash
//commands are in this order: ??, up, down, left, right, enter(ok), delete, quit
int commands[8]={0,49725,8925,17085,33405,41565,39015,31347373};
bool menumode=false;
bool oldmenumode=false;
bool canmenu=false;


//////////////////////////
//from master
byte serval=48;
int oldserval=48;
char serialdata[18]=" ";
int countdowntodoggoad=0;

//stringliterals
char str_spaceparen[]=" (";
char str_not[] =" not";
char str_frozen[] =" frozen";
char str_summerdef[] ="summer";
char str_winterdef[] ="winter";
char str_milli[] ="milli";
char str_solar[] ="solar";
char str_freemem[] ="free memory: ";
char str_long[] ="long";
char str_fired[] ="fired";
char str_for[] =" for ";
char str_word[] ="word";
char str_loop[] ="loop";
char str_forced[] ="forced";
char str_of[] ="of";
char str_byte[] ="byte";
char str_counter[] ="counter";
char str_isfrozen[]="is frozen? (1 if so):";
char str_slab[] ="slab";
char str_togo75[] ="to go 75 ft:"; 
char str_switch[] ="switch";
char str_pump[] ="pump";
char str_change[] ="change";
char str_cleared[] ="cleared";
char str_waitstart[] ="waitstart";
char str_began[] ="began";
char str_pumping[] ="pumping";
char str_event[] ="event";	
char str_cursor[] ="cursor";	
char str_level[] ="level";	
char str_tank[] ="tank";
char str_extreme[] ="extreme";	
char str_forcirculation[] ="for circulation";
char str_data[] ="data";
char str_panel[]="panel";
char str_afterload[] ="afterload";
//char str_ambient[] ="ambient";
char str_hwater[] ="hotwater";
char str_outdoor[] ="outdoor";
char str_basement[] ="basement";
char str_fuel[] ="fuel";
char str_checked[] ="checked";
char str_shutoff[] ="shutoff";
char str_reboot[] ="reboot";
char str_ing[] ="ing";
char str_info[] ="info";
char str_old[] ="old";
char str_type[] ="type";
char str_location[] ="location";
char str_log[] ="log";
char str_reset[] ="reset";
char str_start[] ="start";
char str_setto[] ="set to";
char str_degreesf[]= " degrees F";
char str_morninglogs[] =" morning logs ";
char str_season[] ="season";	
char str_delay[] ="delay ";		
char str_flowrate[] =" flowrate:";	
char str_time[] ="time";	
char str_temperature[] ="temperature";
char str_max[] ="max";	
char str_min[] ="min";
char str_boiler[] ="boiler";
char str_second[] ="second";
char str_minute[] ="minute";
char str_count[] ="count";
char str_suff[] ="sufficiency:";
char str_spaceatspace[] = " at ";
byte str_space = ' ';
byte str_slash = '/';
byte str_colon = ':';
byte str_at = '@';
byte str_s = 's';
byte str_tab=9;//that's the way you get a control character into a byte
//////////////////////////

//default data takes this form (comma-delimited, no spaces). it is char data for use internally to initially represent ir menu states, populated by  master arduino initially and considered read-only:
//SECONDS,MINUTES,HOURS,DAYOFWEEK,DAY,MONTH,YEAR,SEASON,MAXHOTWATER,MINSUMMER,MINWINTER,CYCLETIME
char irinternaldata[]="00,15,15,1,4,5,11,1,155,120,100,122,22,22,22,22,22,22,182,0,"; 
//irinternaldata is mostly only used for debugging; it's the default values for the menu system
//but they are usually quickly overwritten with more valid values from the master 

extern int __bss_end;
extern int *__brkval;

//the first of these is for date, the second for time; have to do a little math later to keep these arrays small

const char *mastercommand[10] = 
{
	"ss",
	"sW",
	"sD",
	"sT",
	"sx",
	"sm",
	"sw",
	"st",
	"xb"
	
}
;

int  dataplace[4][3] = 
{ 
	 
	{7},
	{3},
	{6,5,4},
	{2,1,0},
}
;

const char *legend[2][3] = 
{
	{"YY","MM","DD"},
	{"HH","MM","SS"}
}
;
//new top level menus go here
const char *menuitem[3][11] = 
{ 
	{   
		"Set season",
		"Day of week",
		"Change date",
		"Change time",
		"Set max hotwater",
		"Set min summer",
		"Set min winter",
		"Set cycle time",
		"Reboot slave",
		"Show slave millis",
		"*"
	},
	{
		"Winter",
		"Summer",
		"*"	
	},
	{
		"Sunday",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday",
		"*"	
	}
}
;

//got to change if you increase number of menu items
int arrDataForMenu[14]; //contains int representations of data for display in menu.  
//basically the same data as irinternaldata exploded on comma and its items turned into type integer.
int lcdtop=10;  //got to change if you increase number of menu items

int lcdcursor=0;
int nowmenu=0;
byte ircursor=0;
byte currentlcdlimit=0;
bool linemode=false;
bool bwlDisableRightward=true;


byte ircursorlimit;


void setup() 
{ 
	wdt_disable();
	wdt_enable(WDTO_8S);
	commandpacket[0]='u';
	commandpacket[1]='s';
	Wire.begin(SLAVE); 
	Wire.onReceive(printstuff);
	Wire.onRequest(outgoing); 
	Serial.begin(BAUD_RATE);
	lasteepromread=0;
	lcd.begin(20, 4);
	irrecv.enableIRIn(); 
	populatedefaultarray();
	
 	menumode=false;
	//irval=0;
	lcdcursor=0;
	ircursor=0;
	nowmenu=0;
	linemode=false;
 	//Serial.println("boot up");
} 

void loop () 
{ 
	//for(int i=0; i<10; i++)
	//{
		//Serial.println((int) arrDataForMenu[i]);
	//}
	if(!booted)
	{
		Serial.println("just booted");
		booted=true;
	}
	
	
	//add some serial-based command & control as with master
	if(serval>'9')
	{
		processcommand(serval, 0);
		serval=oldserval;
	
	}
	else if (serval==0) //ends up being zero under some conditions
	{
		serval=oldserval;
	}
	
	
	
	
	
	byte j;
	byte k;
	byte thisbyte;
	long thispower;
	int analogvalue;
	int irval;
 	bool bwlDoNotSave=false;
 	if(millis()>1000)
 	{
 		canmenu=true;  //to help with debugging
 	}
	if (irrecv.decode(&results)  && canmenu) 
	{
		IRresval=results.value;
		IRlow=IRresval % 256;
		IRhigh=(IRresval-IRlow)/256;
		//Serial.print((int) IRhigh);
		//Serial.print(" ");
		//Serial.print((int) IRlow);
		//Serial.println(" ");
		//Serial.println((unsigned int)IRresval);
		irval=ircodelookup(IRresval);
		//Serial.print("          ");
		//for testing new IR codes:
		//Serial.println(IRresval);
		//Serial.print(":");
		//Serial.println(irval);
		if(!menumode)
		{
			bwlDisableRightward=true;
		}
		
		if((!linemode && irval==1)  && lcdcursor>0)//going up in a particular menu
		{
			menumode=true;
			lcdcursor--;
			ircursor=0;
			if(nowmenu>0  && nowmenu<3)
			{
				//Serial.println("menu datachange!");
				//Serial.print(nowmenu);
				//Serial.print(" ");
				//Serial.print(lcdcursor);
				IRchangeInternalData(nowmenu, lcdcursor);
			}
			else
			{
				bwlDisableRightward=false;
			}
		}
		currentlcdlimit=arraylimit(menuitem[nowmenu]);
		if(currentlcdlimit<2  || currentlcdlimit>20)
		{
			linemode=true;	
			bwlDisableRightward=false;
			
		}
		if((!linemode && irval==2 )  && lcdcursor<currentlcdlimit-1 )//going down in a particular menu
		{
			
			menumode=true;
			lcdcursor++;
			if(nowmenu>0  && nowmenu<3)
			{
				//Serial.println("menu datachange!");
				//Serial.print(nowmenu);
				//Serial.print(" ");
				//Serial.print(lcdcursor);
				IRchangeInternalData(nowmenu, lcdcursor);
			}
		 	else
			{
				bwlDisableRightward=false;
			}
		}
		//4 is right and 2 is down, and clicking ok should be the same as moving one to the right
	 
		if(!linemode && (irval==4 || irval==5)     && !bwlDisableRightward  ||  linemode && irval==2)//going into a new menu or up out of linemode
		{
			if(menumode)
			{
				nowmenu=lcdcursor+1;
			}
			menumode=true;
			if(nowmenu==3  || nowmenu==4)//dates or times
			{
				ircursorlimit=5;
				ircursor=0;
			}

			else //usually setting temperatures, which have three digits
			{
				ircursorlimit=2;	
				ircursor=0;
			}
			if(nowmenu<3  && nowmenu>0) //changing season or day of week, so need to set a default from the known data in the menu
			{
				Serial.print("default val:");
				Serial.println(arrDataForMenu[dataplace[nowmenu-1][0]]);
				lcdcursor=arrDataForMenu[dataplace[nowmenu-1][0]];
				bwlDisableRightward=true;
			}
			else
			{
				bwlDisableRightward=false;
			}
			bwlDoNotSave=true;
			
			
		}
		if(!linemode && irval==3  || linemode && irval==1 ) //going out of a menu to a higher level; 3 is left 1 is up
		{
			menumode=true;
			nowmenu=0;
			linemode=false;
			ircursor=0;
			bwlDisableRightward=false;
		 
		}
		if(linemode && irval==3  && ircursor>0)//3 is cursor left  
		{
			
			ircursor--;
		}
		if(linemode &&  irval==4    && ircursor<ircursorlimit)//4 is cursor right
		{
			ircursor++;
		 
		}
		if(irval>47)
		{
			menumode=true;
			IRchangeInternalData( nowmenu,  irval);
			if(ircursor<ircursorlimit)
			{
				ircursor++;
			}
			
		}
		else
		{
			//ircursor=0;	
		}
		if(irval==5  && !bwlDoNotSave)//prepare command for Master to pick up
		{
			
			byte i;
			byte commandpacketcursor=0;
			byte j, thisbyte;
			bool bwlHadNonZero=false;
			int thispower;
			int thisnumber;
			for(i=0; i<2; i++)
			{
				commandpacket[commandpacketcursor]=mastercommand[nowmenu-1][i];
				commandpacketcursor++;
			}
			commandpacket[commandpacketcursor]=' ';
			commandpacketcursor++;
			
			if(nowmenu<3) 
			{
				thisnumber= 48 + arrDataForMenu[dataplace[nowmenu-1][0]];
				commandpacket[commandpacketcursor]=thisnumber;
				commandpacketcursor++;
			}
		 	else if(nowmenu<5   )  //delimited data such as time and date
			{
				for(i=0; i<3; i++)
				{
					thisnumber=arrDataForMenu[dataplace[nowmenu-1][i]];
					//working on it!!
					

					for(j=0; j<2; j++)
					{
						thispower=powerof(10, (1-j));
						thisbyte=thisnumber/(thispower);
				 		
						thisnumber=thisnumber-(thisbyte * (thispower));
						commandpacket[commandpacketcursor]=thisbyte +48;
						commandpacketcursor++;
					}
					commandpacket[commandpacketcursor]=':'; //spaces weren't working
					commandpacketcursor++;
					
				}
				
			}
			else if(nowmenu>4) //for temperatures, we don't store the menu position locations
			{
				thisnumber=arrDataForMenu[nowmenu+3];
				Serial.println((int)thisnumber);
				for(j=0; j<4; j++)
				{
					thispower=powerof(10, (3-j));
					thisbyte=thisnumber/(thispower);
					if(!bwlHadNonZero)
					{
						bwlHadNonZero=thisbyte>0;
					}
					//Serial.println((int)thisbyte);
			 	 
					thisnumber=thisnumber-(thisbyte * (thispower));
					if(thisbyte!=0 || bwlHadNonZero)
					{
						commandpacket[commandpacketcursor]=thisbyte +48;
						//Serial.println(thisbyte +48);
						commandpacketcursor++;
					}
				}
			}
			commandpacket[commandpacketcursor]=0;
			
			
			#if COMMANDTOMASTERMODE == 1
			Serial.println( commandpacket);
			#endif

			ClearLCD();
			lcd.setCursor(0, 1);
			
			Serial.print(str_changes);
			Serial.print(str_saved);
			
			lcd.print(str_changes);
			lcd.print(str_saved);
			
			delay(500);
	 		menumode=false;
	 		irval=0;
	 		lcdcursor=0;
			ircursor=0;
			nowmenu=0;
			linemode=false;
		}
		else if (irval==7)//quit menu mode and tell master to repopulate defaults
		{
			ClearCommandPacket();
			commandpacket[0]='u'; 
			commandpacket[1]='s';
			//Serial.println( commandpacket);
			ClearLCD();
			lcd.setCursor(0, 1);
			
			Serial.print(str_changes);
			Serial.print(str_abandoned);

			lcd.print(str_changes);
			lcd.print(str_abandoned);
			
			delay(500);
	 		menumode=false;
	 		irval=0;
	 		lcdcursor=0;
			ircursor=0;
			nowmenu=0;
			linemode=false;	
		}
		if(irval>0  && menumode)
		{
			//Serial.println( lcdcursor);
			//Serial.println( nowmenu);
			lcdmenu(lcdcursor, nowmenu );
		}
		
		irrecv.resume(); // Receive the next value
	}

	for(k=0; k<7; k++)
	{
		if(k<6)
		{
			int analogvalue=analogRead(k);
			//Serial.println(analogvalue);
			for(j=0; j<2; j++)
			{
				thispower=powerof(256, j);
				thisbyte=analogvalue/thispower;
	 
				analogvalue=analogvalue-(thisbyte * thispower);
				
				slave_packet[(k*2) + j]=thisbyte;
				//Serial.println(thisbyte + 0);
			
			}
		}
		else//how we send back the last eeprom read -- as the final byte in the slave packet
		{
				slave_packet[12]=lasteepromread;
				slave_packet[13]=lasteepromread;
				for(j=1; j<4; j++)
				{
					slave_packet[13+j]=extrabyte[j-1];
				
				}
		}
	}
		//sometimes i need to turn on these lines so i can see what my memory situation is
		//(when i ran this code on an atmega168, the IR library exhausted my memory quickly)
		if(1==2)
		{
			Serial.print("FREEMEMORY ");
			Serial.print(get_free_memory());
			Serial.println("");
		}
 
		oldmenumode=menumode;
	if(heartbeat % 60 ==3)//had used this to debug but i have better mechanisms now
	{
		//lcd.setCursor(0, 0);
		//cd.print((int)heartbeat);
	}
	heartbeat++;
	wdt_reset();
   
 	if (Serial.available()) 
	{
		// read the most recent byte (which will be from 0 to 255)
		oldserval=serval;
		serval = Serial.read() ;
		//Serial.print("this serial: ");
		//Serial.println(serval);
	}
	
	if(countdowntodoggoad==1)
	{
		delay(20000);
		countdowntodoggoad=0;
		
	}
	if(countdowntodoggoad>1)
	{
		countdowntodoggoad--;
		Serial.println((int)countdowntodoggoad);
		lcd.setCursor(0, 1);
		lcd.print((int)countdowntodoggoad);
	}
	if(millis()-timeOfLastFuelCheck>10000)//ten seconds
	{
		timeOfLastFuelCheck=millis();
		int slaveSerVal=-1;
		
		while(slaveSerVal==-1 && millis()-timeOfLastFuelCheck<600)
		{
			byte slavepacket_additional_cursor=18;
			byte subslavepacketdatacursor=0;
			//byte subslavepacketdigitcursor=0;
			int thisData=0;
			Serial.println("3dA");
			
			long millisSlaveReading=millis();
			while(millis()-millisSlaveReading<100)
			{
				if (Serial.available()) //special slave serial
				{
					slaveSerVal=Serial.read();
					if(slaveSerVal!=' ')
					{
						thisData=thisData * 10 + slaveSerVal-48;
					}
					else
					{
						byte thisDataHigh=thisData/256;
						byte thisDataLow=thisData - (thisDataHigh*256);
						
						thisData=0;
						//subslavepacketdigitcursor=0;
						subslavepacketdatacursor++;
						slave_packet[slavepacket_additional_cursor]=thisDataLow;
						slavepacket_additional_cursor++;
						slave_packet[slavepacket_additional_cursor]=thisDataHigh;
						slavepacket_additional_cursor++;
					}
					
					
					
					//send out on the i2c line
				}
			
			}
			//if(thisData)
			//{
			byte thisDataHigh=thisData/256;
			byte thisDataLow=thisData - (thisDataHigh*256);
			slave_packet[slavepacket_additional_cursor]=thisDataLow;
			slavepacket_additional_cursor++;
			slave_packet[slavepacket_additional_cursor]=thisDataHigh;
			//}
		
		}
	}
	delay(200);
	//end loop
} 
 
  
int get_free_memory()
{
  int free_memory;

  if((int)__brkval == 0)
    free_memory = ((int)&free_memory) - ((int)&__bss_end);
  else
    free_memory = ((int)&free_memory) - ((int)__brkval);

  return free_memory;
} 

void outgoing() 
{  
 	byte outsender[3];
	
	//Serial.println("x");
	//Serial.println((int)Wire.receive());
 
 	//Wire.send(slave_packet,18);
	
	 
	
	if(commandbyte==1)//read eeprom
	{
		readvalue=EEPROM.read((unsigned int)address);
		address++;//allow for sequential reads from the EEPROM
		nonlcdmode=false;
 
	}

	else  if (commandbyte==9) //send the slave_packet
	{
		//Serial.println("SLAVE PACKET");
		Wire.send(slave_packet,32);
		nonlcdmode=false;
		return;
	}
	else if (commandbyte==11) //digitalRead
	{
		pinMode(address, INPUT);
		readvalue=digitalRead(address);
		//Serial.println("DIGITAL READ ");
		/*
		outsender[0]=readvalue;
		outsender[1]=readvalue;
		outsender[2]=readvalue;
		Wire.send(outsender,3);
		*/
	 
		nonlcdmode=false;
 
	}

	else if (commandbyte==13) //analogRead
	{
	
		readvalue=analogRead(address);
		//Serial.println("ANALOG READ ");
 
		nonlcdmode=false;
 
	}
	else if (commandbyte==17) //IR value
	{
		readvalue=IRresval % 256;
	}
	else if(commandbyte==15) //RESET!
	{
		void(* resetFunc) (void) = 0;
		resetFunc();
	}
	else if(commandbyte==19) //read menu value
	{
		readvalue=arrDataForMenu[address] ;
	}
	else if(commandbyte==21) //pick up command from menu system
	{
		#if COMMANDTOMASTERMODE == 0
		Wire.send(commandpacket,18); //doesn't work when commandpacket is char, only byte!!
		#endif
		ClearCommandPacket();
		nonlcdmode=false;
		return;
	}
	outsender[0]=readvalue;
	outsender[1]=readvalue;
	outsender[2]=readvalue;
 
	Wire.send(outsender,3);
	commandbyte=0;
	return;
} 

void ClearCommandPacket()
{
	byte i;
	for(i=0; i<18; i++)
	{
		commandpacket[i]=0;
	}
}

void setuprequest()
{
	byte b;
	nonlcdmode=true;
	outcount=0;
	commandbyte=99;
 	
	
	while(Wire.available() )
	{
		b=Wire.receive();
		//return;

		//order: command byte, addressbyte high, addressbyte low, value
		if(outcount==0)
		{
			commandbyte=b;
			if(commandbyte==9)
			{
	
			}
		}
		else if(outcount==1  && commandbyte!=9)
		{

			high=(byte)b;
		}
		else if(outcount==2  && commandbyte!=9)
		{
			low=(byte)b;
		}
		else if(outcount==3  && commandbyte!=9)
		{
			readvalue=b;
		}
		if(commandbyte!=9)
		{
			address=(unsigned int)high*256 + low;
		}
		if(1==2)
		{
			Serial.print("^");
			Serial.print((char)high);
			Serial.print(" ");
			Serial.print((char)low);
			Serial.print(" ");
			Serial.print(address);
			Serial.println("");
		}
		outcount++;
	}

	if (commandbyte==2) //write eeprom
	{
		//Serial.print("EEPROM WRITE ");
		Serial.print(address);
		//Serial.print(":");
		Serial.print((int) readvalue);
		Serial.println("");
		EEPROM.write(address, readvalue);
		nonlcdmode=false;
 
		//deliverable[0]=77;
		//Wire.send(deliverable,1);
	
	}
	else if (commandbyte==10) //digitalWrite
	{
	
		pinMode(address, OUTPUT);
		digitalWrite(address, readvalue);
		//Serial.println("DIGITAL WRITE ");
		nonlcdmode=false;
	 
		
		//printstuff(1) ;
	}
	else if (commandbyte==14) //analogWrite
	{
	
		analogWrite(address, readvalue);
		//Serial.println("ANALOG WRITE ");
		nonlcdmode=false;
		
		//printstuff(1) ;
	} 
	else if (commandbyte==16) //setDefaultMenuValues
	{

		arrDataForMenu[address]= readvalue;
 
		nonlcdmode=false;
		canmenu=true;
		//Serial.println("can menu!! ");
		//Serial.println("11:");
		//Serial.println(arrDataForMenu[11]);
		//printstuff(1) ;
	} 
	nonlcdmode=false;
	return;
}

 
void printstuff(int number) //display delimited data from Master on the LCD
{ 

	//Serial.println(" ");
	//Serial.println(number);
	if(number<1)
	{
		return; //wrong kind of access!
	}
	char * thisitem[40];
	int count=0;
	int fieldcount=0;
	int itemcount=0;
	char b;
	char fielddelimiter='|';
	char columndelimiter='^';
	int thistemp;
	int i;
	int j;
	int thisint;
	int charpos;
	
	byte extrabytecounter=0;
 	byte k;
	outcount=0;
	bool bwlDoingCharactersNow=false;
	charpos=0;
 
 	thisint=0;
	
	while(Wire.available()>0  && !nonlcdmode) 
	{
		
		b=Wire.receive();
 
		if(b=='!' && count==0 || nonlcdmode)
		{
			setuprequest();
			return;

		}
		//Serial.print('%');
		//Serial.println(b);
		if(b==fielddelimiter)
		{
			//Serial.print("$");
			if(fieldcount==0)
			{
				//Serial.print("#");
				xpos[itemcount]=thisint;
				thisint=0;
				charpos=0;
			}
			else if(fieldcount==1)
			{
				ypos[itemcount]=thisint;
				thisint=0;
				charpos=0;
			}
			//the following allow the master to pass in a list of up to four bytes to be stored consecutively
			else if(fieldcount==2)
			{
				extrabyte[0]==thisint;
				extrabytecounter++;
			}
			else if(fieldcount==3)
			{
				extrabyte[1]==thisint;
				extrabytecounter++;
			}
			else if(fieldcount==4)
			{
				extrabyte[2]==thisint;
				extrabytecounter++;
			}
			fieldcount++;
		}
		else if (b==columndelimiter)
		{
			//Serial.print("@");
			itemcount++;
			thisint=0;
			fieldcount=0;
			charpos=0;
			bwlDoingCharactersNow=false;
		}
		else
		{
			if(fieldcount<2  || (b>47  && b<58  && (charpos==0  || !bwlDoingCharactersNow)))
			{
				thisint=thisint*10+(b-48);
			}
			else
			{
				charblock[charpos][itemcount]=b;
				charblock[charpos+1][itemcount]=0;
				charpos++;
				thisint=0;
				bwlDoingCharactersNow=true;
			}
			
		}
		//Serial.print(thisbyte[count]);
		//Serial.print("*");
 		
 
		count++;
		//number--;
	}
 	if(count>0  && !nonlcdmode)
	{
		//Serial.println(" ");
		//Serial.println(itemcount);
		//Serial.print(xpos[i]);
		//Serial.print(" ");
		//Serial.print(ypos[i]);
		//Serial.println(charblock[j]);
		//Serial.println("");
		for(i=0; i<=itemcount; i++)
		{
			if(1==1 && !menumode)
			{
				//Serial.print("x:");
				//Serial.print(xpos[i]);
				//Serial.print(" y:");
				///Serial.print(ypos[i]);
				//Serial.println(" ");
				if(xpos[i]<100)
				{
					
					lcd.setCursor(xpos[i], ypos[i]);
					for(j=0; j<20; j++)
					{
						if(charblock[j][i]!=0)
						{
							lcd.print(charblock[j][i]);
							//Serial.print(charblock[j][i]);
						}
					}
				}
				else if (xpos[i]<1000)//if we're well outside the range of the LCD (above 100 and below 1000), then use this command to set the pin at xpos-100 with the value of ypos
				{
					
					if( ypos[i]<256)
					{
						Serial.println("found a pinmoder");
						 pinMode(xpos[i]-100, OUTPUT);
						 if(ypos[i]>0)
						 {
							 digitalWrite(xpos[i]-100, 1);
						 }
						 else
						 {
						 	digitalWrite(xpos[i]-100,0);
						 
						 	analogWrite(xpos[i]-100, ypos[i]);
						 }
					 }
					 else
					 {
					 	if(ypos[i]==256)
						{
							Serial.println("found a digital pin reader");
							pinMode(xpos[i]-100, INPUT);
							lastpinread=digitalRead(xpos[i]-100);
						}
						else
						{
							Serial.println("found an analog pin reader");
							lastpinread=analogRead(xpos[i]-100);
						}
					 	
					 	
					 }
				}
				else //use this to write in the slave EEPROM at the address of xpos-1000.
				{
					
					if( ypos[i]<256)
					{
						Serial.println("found an eeprom writer");
						EEPROM.write(xpos[i]-1000, ypos[i]);
						if(extrabytecounter>0)
						{
							
							//write out any more bytes that were sent, up to three
							for(k=0; k<extrabytecounter; k++)
							{
								EEPROM.write(k + 1+ (xpos[i]-1000), extrabyte[k]);
							}
						}
						lasteepromread=ypos[i];
					}
					else if(1==2)
					{
						Serial.println("found an eeprom reader");
						lasteepromread=EEPROM.read(xpos[i]-1000);
						for(k=0; k<3; k++)
						{
							//Serial.print(k+xpos[i]+1-1000);
							//Serial.print(": ");
							extrabyte[k]=EEPROM.read(k+1+xpos[i]-1000);
							//Serial.print((int)extrabyte[k]);
							//Serial.print(", ");
						}
						Serial.println("");
					}
				}
				//Serial.println(" ");
			}
			//Serial.println(" ");
		}
	
	}
 
	if(1==2)
	{
		Serial.print(temp1);
	 	Serial.print(" ");
		Serial.print(temp2);
		Serial.print(" ");
		Serial.print(temp3);
	 	Serial.print(" ");
		Serial.print(temp4);
		Serial.print(" ");
		Serial.println(" ");
	}
	//lcd.print(thisbyte + 0);
   
} 
 

long powerof(long intin, byte powerin)
//raises intin to the power of powerin
//not using "pow" saves me a lot of Flash memory
{
	long outdata=1;
	byte k;
	for (k = 1; k <powerin+1; k++)
	{
		outdata=outdata*intin;
	}
	return outdata;
}

int ircodelookup(unsigned int inval)
//this will vary for different IR remotes but i'm setting it up for the one i happen to have
{
 
	unsigned int i;
	unsigned int outval=0;
	//Serial.println(sizeof(integers)/sizeof(int));


	for(i=0; i< (sizeof(commands)/sizeof(int)); i++)
	{
		if((unsigned int)commands[i]==(unsigned int)inval)
		{
			outval=i;
		}
		
	}
	
	for(i=0; i<(sizeof(integers)/sizeof(int)); i++)
	{
		if((unsigned int)integers[i]==(unsigned int)inval)
		{
			if(i==10)
			{
				outval=58;
			}
			else if (i==11)
			{
				outval=45;
			}
			else
			{
				outval = i + 48;
			}
		}

		
	}
	return outval;

}

void printchars(byte numberofchars, char charin, byte mode)
{
	byte i;
	for(i=0; i<numberofchars; i++)
	{
		if(mode==0)
		{
			Serial.print(charin);
		}
		else if(mode==1)
		{
			Wire.send(charin);
		}
		else if(mode==2)
		{
			lcd.print(charin);
		}
	}
}

void lcdmenu(int placement, int level )
{ 
	//Serial.print(placement);
	//Serial.print("= =");
	//Serial.println(level);
	int i=0;
	int locallow, localhigh, intmaxatonce;
	byte thisy=0;
	char pre=' ';
	char * stufftoprint;
	intmaxatonce=4;
	
	ClearLCD();
 	if(level<3)
 	{
		if(placement<intmaxatonce)
		{
			locallow=0;
			localhigh=locallow+intmaxatonce;
		}
		else
		{
			locallow=	placement;
			localhigh=locallow+intmaxatonce;
		}
		if(localhigh>lcdtop)
		{
			
			localhigh=lcdtop;	
			locallow=	localhigh-intmaxatonce;	
		}
	 	
		for(i=locallow; i<localhigh; i++)
		{
			if(i==placement)
			{
				pre='+';
			}
			else
			{
				pre=' ';	
			}
			Serial.print(pre);
			stufftoprint=(char *)menuitem[level][ i];
				
			if(stufftoprint[0]!='*')
			{
				Serial.println(stufftoprint);
				lcd.setCursor(0, thisy);
				lcd.print(pre);
				lcd.print(stufftoprint);
				lcd.print("");
				thisy++;
			}
			else
			{
				break;
			}
		
		}
	}
 	else
 	{
 		if(level==4)
 		{
 			displaydelimiteddata(level);
 			DisplayCursor(level);
 		}
 		else if(level==3)
 		{
 			displaydelimiteddata(level);
 			DisplayCursor(level);
 		}
		else if(level==9) //9 is reboot!
 		{
			lcd.setCursor(0, 0);
			lcd.print("Rebooting slave");
			Serial.print("Rebooting slave");
			countdowntodoggoad=10;
			return;
		}
		else if(level==10) //10 is display millis
 		{
			lcd.setCursor(0, 0);
			lcd.print("Millis: ");
			lcd.setCursor(0, 1);
			lcd.print(millis());
			Serial.print("Millis: ");
			Serial.println(millis());
			//delay(3000);
			return;
		}
 		else if(level>4) //5 is season!
 		{
 			displaynondelimiteddata(level);
 			DisplayCursor(level);
 		}

 	}
}


byte arraylimit(const char ** arrIn) //looks for the end of an array as tagged by "*"
{
	byte i=0;
	for(i=0; i<200; i++)
	{
		if(arrIn[i][0]=='*')
		{
			return i;
			break;
			
		}
	}
	return 200;
}

 
void populatedefaultarray() //not really even necessary except to give default values should the master not send them
{
	byte i,j;
	byte thiscounter=0;
	byte charinthis=0;
	char thischar;
	byte thisseries[3];
	
	for(i=0; i<70; i++)
	{
		//Serial.println((int) i);
		thischar=irinternaldata[i];
		if(thischar==',')
		{
			for(j=0; j<charinthis; j++)
			{
				//Serial.print((int) j);
				//Serial.print(" ");
				//Serial.print((int)thisseries[j]);
				//Serial.print(" ");
				//Serial.print((charinthis-1)-j);
				//Serial.print(" ");
				//Serial.print((int) powerof(10,(charinthis-1)-j));
				//Serial.println(" ");
				arrDataForMenu[thiscounter]+=(int) thisseries[j] * powerof(10,(charinthis-1)-j);
			}
			thiscounter++;
			charinthis=0;
			
		}
		else
		{
			thisseries[charinthis]=thischar-48;
			charinthis++;
		}
	
	
	}

}

unsigned long powerof(int intin, byte powerin)
//raises intin to the power of powerin
//not using "pow" saves me a lot of Flash memory
{
  unsigned long outdata=1;
  byte k;
  for (k = 1; k <powerin+1; k++)
  {
    outdata=outdata*intin;
  }
  return outdata;
}

void pwlvin(byte inval)
{
	if((int)inval<10)
	{
		Serial.print("0");
 
		lcd.print("0");
  
	}
	Serial.print((int)inval);
	lcd.print((int)inval);
}

void pwlv3in(int inval)
{
	if((int)inval<100)
	{
		Serial.print("0");
		lcd.print("0");
	}
	if((int)inval<10)
	{
		Serial.print("0");
		lcd.print("0");
	}
	Serial.print((int)inval);
	lcd.print((int)inval);
}

void displaydelimiteddata(  byte level)
{
	byte thisy=0;
	ClearLCD();
	Serial.println(menuitem[0][level-1]);
	
 

	lcd.setCursor(0, thisy);
	lcd.print(menuitem[0][level-1]);
	thisy++;
				
	char separator='-';
	if(level==4)
	{
		separator=':';	
	}
	lcd.setCursor(0, thisy);
	for(byte i=0; i<3; i++)
	{
		Serial.print(legend[level-3][i]);
		

		
		lcd.print(legend[level-3][i]);
	 
		
		if(i<2)
		{
			Serial.print(separator);
			lcd.print(separator);
		}
	}
	Serial.println("");
	thisy++;

	lcd.setCursor(0, thisy);
	for(byte i=0; i<3; i++)
	{
		pwlvin(arrDataForMenu[dataplace[level-1][i]]);
		if(i<2)
		{
			Serial.print(separator);
			lcd.print(separator);
		}
	}
	Serial.println("");
	thisy++;

	lcd.setCursor(0, thisy);
	
}

void displaynondelimiteddata(byte level)
{
 
	byte thisy=0;
	ClearLCD();
	lcd.setCursor(0, thisy);
	lcd.print(menuitem[0][level-1]);
	thisy++;
	
	Serial.println(menuitem[0][level-1]);
	

	lcd.setCursor(0, thisy);
	pwlv3in(arrDataForMenu[level+3]);
	 

	//lcd.setCursor(0, thisy);
	//printchars(20, ' ', 2);
	//lcd.setCursor(0, thisy);
	if(level<8)
	{
		lcd.print(str_degF);
		Serial.print(str_degF);
	}
	else if(level<9)
	{
		lcd.print(str_deciseconds);
		Serial.print(str_deciseconds);
	}
	else// if(level==10)
	{

	}
	//else 
	//{
		//future expansion
	//}
	Serial.println("");
	thisy++;

	lcd.setCursor(0, thisy);
 
}

void ClearLCD()
{
	byte i;
	for(i=0; i<4; i++)
	{
		lcd.setCursor(0, i);
		printchars(20, ' ', 2);
	}
}

void IRchangeInternalData(byte level, byte irval)
{
	//only worry about arrDataForMenu, not irinternaldata!
	byte i;
 	int arrSeq[3] ;
	byte thispower;
 	byte otherpart;
	int thisval;
	//next line refers to displaydelimiteddata order:
	//SECONDS,MINUTES,HOURS,DAYOFWEEK,DAY,MONTH,YEAR,MAXHOTWATER,MINSUMMER,MINWINTER,CYCLETIME
	//Serial.println((int)level);
	if(level==3  || level==4)
	{
		for(i=0; i<6; i++)
		{
			arrSeq[(int)i/2]=dataplace[level-1][i/2];
			if((int)i % 2==1)
			{
				thispower=0;
			}
			else 
			{
				thispower=1;
			}
			if((int)i==(int)ircursor)
			{
				thisval=arrDataForMenu[arrSeq[(int)i/2]];
				arrDataForMenu[arrSeq[(int)i/2]]=   SwapInDigit(irval-48, thispower, thisval)  ; 
			} 
		}
	}
	else if (level>4)
	{
		arrSeq[0]=level+3; //where a temperature cutoff/time value falls in the internal list
		for(i=0; i<3; i++)
		{
			thispower=2-i;	
			thisval=arrDataForMenu[arrSeq[0]];
			//Serial.println((int)thisval);
			if((int)i==(int)ircursor)
			{
				
				arrDataForMenu[arrSeq[0]]=   SwapInDigit(irval-48, thispower, thisval)  ; 
			}
		}
		
	}
	else
	{
		arrSeq[0]=dataplace[level-1][0];
		//Serial.print("valontherebound:");
		//Serial.println(arrSeq[0]);
		arrDataForMenu[arrSeq[0]]=irval;
	}
}

int SwapInDigit(byte inval, byte distancefromones, int originalvalue)
//allows me to take an integer and swap in a new digit to replace an existing one
//works for integers up to ten thousand
{
	int out=0;
	int scanval;
	for(byte i=6; i<255; i--)//weird how i had to do that freaky 255 test
	{
	
		scanval=originalvalue/powerof(10, i);
		if(distancefromones==i  )
		{
			out=out+ inval*powerof(10, i);
		}
		else
		{
			out=out+ scanval*powerof(10, i);
		}
		originalvalue=originalvalue-scanval* powerof(10, i);
	}
	return out;
	
}

void DisplayCursor(byte level)
{
 
	//Serial.println("");
	for(byte i=0; i<ircursor; i++)
	{
		Serial.print("-");
		lcd.print("-");
		if((i+1) % 2==0  && i>0  && level>2  && level<5)
		{
			Serial.print("-");
			lcd.print("-");
		}
	}
	Serial.println("^");
	lcd.print("^");
	 
}

void processcommand(byte initialcommand, byte type) //type==0 means serial, 1 means via I2C from the slave
{
 
	char readbyte=str_space;
	byte cursor=0;
	char secondcharacter=str_space;
	unsigned long possiblefirstnumber=-1;
	
	byte foreepromwrite;
	long rawserial;
	int thisbyte=-1;
	byte i;
	//Serial.print("initialcommand: ");
	//Serial.print(initialcommand);
	//Serial.print(" type: ");
	//Serial.println((int)type);
	if(initialcommand>64  && initialcommand<173) //letters, mostly
	{

		while(readbyte>0)
		{
			
			if(type==0)
			{
				readbyte=Serial.read();
			}
			else if(type==1)
			{
				if(Wire.available())
				{
					readbyte=Wire.receive();	
					//Serial.println(readbyte);
				}
				else
				{
					return;	
				}
			}
			serialdata[cursor]=  readbyte;
			cursor++;
			if(secondcharacter==str_space)
			{
				secondcharacter=readbyte;
			}
			if(readbyte==str_space  && possiblefirstnumber==-1)
			{
				possiblefirstnumber=string2number(serialdata);
				cursor=0;
			}
		}
		serialdata[--cursor]='\0';
		rawserial=string2number(serialdata);
		
		if (initialcommand=='?')  //display help
		{
			//displayhelp(); //don't do this on slave
		}
		else if (initialcommand=='m')  //show memory
		{
			Serial.print(str_freemem);
			Serial.print(get_free_memory());
			Serial.println("");
		}
		else if (initialcommand=='r')
		{
			if(secondcharacter=='b') //'rb' means "reboot"
			{
				Serial.print(str_reboot);
				Serial.print(str_ing);
				Serial.print("...");
				Serial.println("");
				void(* resetFunc) (void) = 0;
				resetFunc();
				setup();
			}
		}
		else if (initialcommand=='y')
		{
			if(secondcharacter=='t')		//'yt' means "you there?"
			{
				Serial.println("Yes I am here.");
			}
		
		}
		else if (initialcommand=='d')
		{
			if (secondcharacter=='C') //'dC': display millis
			{
	 			Serial.print("Millis: ");
				Serial.println(millis());
			}
			if(secondcharacter=='s')		//'ds' means "display solar log"
			{
				//displaymorningsolarlog(); //don't do this on slave
			}
			else if(secondcharacter=='l') 	//'dl' means "display long"
			{
			 
			}
			else if(secondcharacter=='n') 	//'dn' means "display clock compensation"
			{
 
			}
			else if(secondcharacter=='e') 	//'de' means "display extremes, in this case those extremes and times
			{
			 
			}
			else if(secondcharacter=='f') 	//'df' means "display fuel info
			{
				 
			}
			else if(secondcharacter=='b') //'db' means "display boiler log 
			{
				 
			}
			else if(secondcharacter=='v') //'dv' means "display event log 
			{
				 
			}
			else if(secondcharacter=='t') //'dt' means "display boiler count"
			{
	 
			}
			else if(secondcharacter=='c') //'dc' means "display cursors"
			{
 
			}
			else if(secondcharacter=='r')//'dr' means "display real time variables"
			{
				 
			}
			else //display byte data in EEPROM
			{
	 
			}
	
			
			
		}
		else if (initialcommand=='c')
		{
			if (secondcharacter=='e') //'ce': clear extreme data
			{
	 
			}
			else if (secondcharacter=='f') //'cf': clear fuel info
			{
 
			}
			else if (secondcharacter=='b') //'cb': clear boiler log location
			{
 
			}
			else if (secondcharacter=='v') //'cv': clear event log location
			{
 
			}
			else if(secondcharacter=='i') //'ci' means "clear insufficiency force"
			{	
				
		 
			}
		}
		else if (initialcommand=='s')
		{

			if (secondcharacter=='x') //'sx': set switchover temp from hot water to slab (makes sense mostly in the summer)
			{
	 
			}
			if (secondcharacter=='n') //'sn': set clock compensation)
			{
 
			}
			else if(secondcharacter=='c'  || secondcharacter=='W' || secondcharacter=='T' || secondcharacter=='D'  )//'sc' means "set clock -- that is, real time clock"
			{
				 
				
			}
			else if(secondcharacter=='b')
			{
		 
			}
			
			else if (secondcharacter=='t') //'st': set time of delay of main loop in deciseconds
			{
				
 
			}
			else if (secondcharacter=='d') //'sd': set time of delay of relay action until this number of unchanging deciseconds
			{
			
 
			}
			else if(secondcharacter=='m'  || secondcharacter=='l'  )  //'sm' or 'sl'; set minimum summer temperature to run panel
			{
 
			}
			else if(secondcharacter=='w' )  //'sw'; set minimum winter temperature to run panel
			{
 
			}
			else if(secondcharacter=='s') //'ss' means "season set"
			{
 
			}
			else if(secondcharacter=='f') //'sf' means "set/show frozen"
			{
			
 
			}

		
		}
		else if(initialcommand=='f') 
		{
			if(secondcharacter=='i') //'fi': force insufficiency
			{
	 
			}
		}
		else if(initialcommand=='g')
		{
			if(secondcharacter=='d') //'gd' means "goad dog" -- basically test to see if watchdog trips during a 20 second delay after so many times through the loop.
			//enter gd 20 to see the dog goaded 20 loops in the future. system should reset nicely at that point and start up again.
			//while the countdown happens, every other line is the count until goading
			{
		 
				countdowntodoggoad=rawserial;
		 
			}
 
		
		}
		else if(initialcommand=='x') //'xf' means "check fuel" in oil tank for boiler
		{
			if(secondcharacter=='f')
			{
			 
			}
		}
		else if(initialcommand=='u') //'us' means "update slave" for menu system;
		{
			if(secondcharacter=='s')
			{
				 ;
				return;
			}
		}
		else if(initialcommand=='w')
		{
			if(possiblefirstnumber!=-1  && (secondcharacter=='e'  || secondcharacter=='b')) //'we' or 'wb' means "write eeprom" or "write byte"
			{
 
			}
			else if (possiblefirstnumber>-1  && secondcharacter=='l')//'wl' means "write long"
			{
 
			}
		
		}
		if(thisbyte!=-1)
		{
 
		}

	}		
	if(type==0)
	{
		Serial.flush();
	}
}


long string2number(char datain[18])
//parses a string into a long, August 9 2008
{
	int i;
	int thischar;
	int scale=1;
	int negscale=1;
	unsigned long out=0;
	for (i = 18; i > -1; i--)
	{
		thischar=datain[i];
		if( thischar=='\0')//clear the number if we're reading from beyond the zero terminator -- total primitive C thing
		{
			out=0;
			scale=1;
		}
		else if(thischar>47  && thischar<58)
		{
			out=out+(thischar-48)*powerof(10, scale-1);
			scale++;
		}
		else if(thischar=='-' )
		{
			negscale=-1  ;
		}
	}
	if(scale==1)
	{
		out=-1;
	}
	return negscale * out;
}
