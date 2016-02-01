#include <CoreFoundation/CoreFoundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

// some MIDI constants:
enum {
	kMidiMessage_ControlChange      = 0xB,
	kMidiMessage_ProgramChange      = 0xC,
	kMidiMessage_BankMSBControl     = 0,
	kMidiMessage_BankLSBControl     = 32,
	kMidiMessage_NoteOn             = 0x9,
	kMidiMessage_NoteOff            = 0x8
};

/* Create an AudioUnit */
AudioUnit synthUnit;

#pragma mark Audio Graph Setup

static void audioGraphSetup() {
	AUGraph graph;
	AUNode outputNode, mixerNode, synthNode;
	//AudioUnit synthUnit;

	//Setup Graph
	NewAUGraph(&graph);

	AudioComponentDescription cd;
	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;
	cd.componentType = kAudioUnitType_Output;
	//cd.componentSubType = kAudioUnitSubType_HALOutput;
	cd.componentSubType = kAudioUnitSubType_DefaultOutput;

	AUGraphAddNode(graph, &cd, &outputNode);
	AUGraphOpen(graph);
	AUGraphInitialize(graph);
	AUGraphStart(graph);

	//New NODES
	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;
	cd.componentType = kAudioUnitType_MusicDevice;
	cd.componentSubType = kAudioUnitSubType_DLSSynth;

	AUGraphAddNode(graph, &cd, &synthNode);
	AUGraphNodeInfo(graph, synthNode, NULL, &synthUnit);

	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;
	cd.componentType = kAudioUnitType_Mixer;
	cd.componentSubType = kAudioUnitSubType_StereoMixer;

	AUGraphAddNode(graph, &cd, &mixerNode);

	//Connect NODES
	AUGraphConnectNodeInput(graph, mixerNode, 0, outputNode, 0);
	AUGraphConnectNodeInput(graph, synthNode, 0, mixerNode, 0);
	//Update Graph
	AUGraphUpdate(graph,NULL);
}

/* Establisth MIDIRead and MIDI Notify callbacks which will get MIDI data from the devices */
#pragma mark CoreMIDi callbacks
static void	MIDIRead(const MIDIPacketList *pktlist, void *refCon, void *srcConnRefCon) {
    
    //Reads the source/device's name which is allocated in the MidiSetupWithSource function.
    char *source = srcConnRefCon;
    
    //Extracting the data from the MIDI packets receieved.
    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
	Byte note = packet->data[1] & 0x7F;
    Byte velocity = packet->data[2] & 0x7F;
    
    for (int i=0; i < pktlist->numPackets; i++) {
        
		Byte midiStatus = packet->data[0];
		Byte midiCommand = midiStatus  & 0xF0;
                
		if ((midiCommand == kMidiMessage_NoteOn<<4) || //note on
			(midiCommand == kMidiMessage_NoteOff<<4)) { //note off

            Byte channel = midiStatus & 0x0F;

            MusicDeviceMIDIEvent(synthUnit, midiStatus, note, velocity, 0);
            
            printf("%s - NOTE : %d | %d | %d\n", source, note, velocity, channel);
            
		} else {
        
            printf("%s - CNTRL  : %d | %d\n", source, note, velocity);
        }
		
        //After we are done reading the data, move to the next packet.
        packet = MIDIPacketNext(packet);
        
	}
    
}

void NotificationProc (const MIDINotification  *message, void *refCon) {
	printf("MIDI Notify, MessageID=%d,\n", message->messageID);
}

#pragma mark MIDI Source list
void listSources ()
{
    unsigned long sourceCount = MIDIGetNumberOfSources();
    for (int i=0; i<sourceCount; i++) {
        MIDIEndpointRef source = MIDIGetSource(i);
        CFStringRef endpointName = NULL;
        MIDIObjectGetStringProperty(source, kMIDIPropertyName, &endpointName);
        char endpointNameC[255];
        CFStringGetCString(endpointName, endpointNameC, 255, kCFStringEncodingUTF8);
        printf("Source %d - '%s'\n", i, endpointNameC);
    }
}

#pragma mark MIDI Setup
void MIDISetupWithSource(int sourceNo)
{
    MIDIClientRef client;
	MIDIClientCreate(CFSTR("SuperSimpleMIDIIn"), NotificationProc, synthUnit, &client);
    
	MIDIPortRef inPort;
	MIDIInputPortCreate(client, CFSTR("Input port"), MIDIRead, synthUnit, &inPort);
    
    MIDIEndpointRef source = MIDIGetSource(sourceNo);
    CFStringRef endpointName = NULL;
    MIDIObjectGetStringProperty(source, kMIDIPropertyName, &endpointName);
	char endpointNameC[255];
	CFStringGetCString(endpointName, endpointNameC, 255, kCFStringEncodingUTF8);

    MIDIPortConnectSource(inPort, source, endpointNameC);
    printf("Recieving MIDI data from source %d '%s'\n", sourceNo, endpointNameC);
}

#pragma mark - Main
int main (int argc, const char * argv[])
{
	@autoreleasepool {

		audioGraphSetup();

		//send program changes and notes
		//using 3 different channels
		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_ProgramChange<<4|0, 0, 0, 0);
		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_ProgramChange<<4|1, 10, 0, 0);
		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_ProgramChange<<4|2, 20, 0, 0);
		sleep(1);

		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_NoteOn<<4|0, 60, 80, 0);
		sleep(1);
		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_NoteOff<<4|0, 60, 0, 0);

		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_NoteOn<<4|1, 60, 80, 0);
		sleep(1);
		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_NoteOff<<4|1, 60, 0, 0);

		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_NoteOn<<4|2, 60, 80, 0);
		sleep(1);
		MusicDeviceMIDIEvent(synthUnit, kMidiMessage_NoteOff<<4|2, 60, 0, 0);

		listSources();           //See which sources you'd like to connect and then connect them as below.

		int source = 0;
		printf("Enter the source to use (0-16):\n");
		scanf("%d",&source);

		MIDISetupWithSource(source);
		//MIDISetupWithSource(6);  //Connecting source 6 - Novation Launchpad.
		//MIDISetupWithSource(7);  //Connecting source 7 - Livid Code.

		CFRunLoopRun();          //Loop this for constant data updates.

	}
	return 0;
}

#pragma mark Unused function for next commit.
void setupMIDI() { //Currently unused function.
	
	MIDIClientRef client;
	MIDIClientCreate(CFSTR("SuperSimpleMIDIIn"), NotificationProc, synthUnit, &client);
    
	MIDIPortRef inPort;
	MIDIInputPortCreate(client, CFSTR("Input port"), MIDIRead, synthUnit, &inPort);
    
    unsigned long sourceCount = MIDIGetNumberOfSources();
    
    for (int i=0; i<sourceCount; i++) {
        MIDIEndpointRef src = MIDIGetSource(i);
        CFStringRef endpointName = NULL;
        MIDIObjectGetStringProperty(src, kMIDIPropertyName, &endpointName);
        char endpointNameC[255];
        CFStringGetCString(endpointName, endpointNameC, 255, kCFStringEncodingUTF8);
        
        MIDIPortConnectSource(inPort, src, (void*)"NameOfDevice"); //This works.
        MIDIPortConnectSource(inPort, src, (void*)endpointNameC); //This doesn't work..
        char *string1 = endpointNameC;
        MIDIPortConnectSource(inPort, src, (void*)string1); //and this doesn't work either. FIX needed for automation.
    }
}

