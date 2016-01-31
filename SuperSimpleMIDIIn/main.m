
#include <CoreFoundation/CoreFoundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

/* Create an AudioUnit */
AudioUnit instrumentUnit;

#pragma mark Audio Graph Setup

static void audioGraphSetup() {
    AUGraph audioGraph;
    NewAUGraph(&audioGraph);

    AudioComponentDescription cd;
    AUNode outputNode;
    AudioUnit outputUnit;

    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;

    AUGraphAddNode(audioGraph, &cd, &outputNode);
    AUGraphNodeInfo(audioGraph, outputNode, &cd, &outputUnit);

    AUNode mixerNode;
    AudioUnit mixerUnit;

    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    cd.componentType = kAudioUnitType_Mixer;
    cd.componentSubType = kAudioUnitSubType_StereoMixer;

    AUGraphAddNode(audioGraph, &cd, &mixerNode);
    AUGraphNodeInfo(audioGraph, mixerNode, &cd, &mixerUnit);

    AUGraphConnectNodeInput(audioGraph, mixerNode, 0, outputNode, 0);

    AUGraphOpen(audioGraph);
    AUGraphInitialize(audioGraph);
    AUGraphStart(audioGraph);

    AUNode synthNode;
    //AudioUnit synthUnit;

    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    cd.componentType = kAudioUnitType_MusicDevice;
    cd.componentSubType = kAudioUnitSubType_DLSSynth;

    AUGraphAddNode(audioGraph, &cd, &synthNode);
    AUGraphNodeInfo(audioGraph, synthNode, &cd, &instrumentUnit);

    AUGraphConnectNodeInput(audioGraph, synthNode, 0, mixerNode, 0);

    AUGraphUpdate(audioGraph, NULL);
    CAShow(audioGraph);

    MusicDeviceMIDIEvent(instrumentUnit, 0x90, 60, 127, 0);
    sleep(1);
    MusicDeviceMIDIEvent(instrumentUnit, 0x90, 62, 127, 0);
    sleep(1);
    MusicDeviceMIDIEvent(instrumentUnit, 0x90, 64, 127, 0);
    sleep(1);
}

/* Establisth MIDIRead and MIDI Notify callbacks which will get MIDI data from the devices */
#pragma mark CoreMIDi callbacks
static void	MIDIRead(const MIDIPacketList *pktlist, void *refCon, void *srcConnRefCon) {
    
    //Reads the source/device's name which is allocated in the MidiSetupWithSource function.
    const char *source = srcConnRefCon;
    
    //Extracting the data from the MIDI packets receieved.
    MIDIPacket *packet = (MIDIPacket *)pktlist->packet;
	Byte note = packet->data[1] & 0x7F;
    Byte velocity = packet->data[2] & 0x7F;
    
    for (int i=0; i < pktlist->numPackets; i++) {
        
		Byte midiStatus = packet->data[0];
		Byte midiCommand = midiStatus  & 0xF0;
                
		if ((midiCommand == 0x90) || //note on
			(midiCommand == 0x80)) { //note off

            Byte channel = midiStatus & 0x0F;

            MusicDeviceMIDIEvent(instrumentUnit, midiStatus, note, velocity, 0);
            
            NSLog(@"%@ - NOTE : %d | %d | %d", source, note, velocity, channel);
            
		} else {
        
            NSLog(@"%@ - CNTRL  : %d | %d", source, note, velocity);
        }
		
        //After we are done reading the data, move to the next packet.
        packet = MIDIPacketNext(packet);
        
	}
    
}

void NotificationProc (const MIDINotification  *message, void *refCon) {
	NSLog(@"MIDI Notify, MessageID=%d,", message->messageID);
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
        NSLog(@"Source %d - %s", i, endpointNameC);
    }
}

#pragma mark MIDI Setup
void MIDISetupWithSource(int sourceNo)
{
    MIDIClientRef client;
	MIDIClientCreate(CFSTR("SuperSimpleMIDIIn"), NotificationProc, instrumentUnit, &client);
    
	MIDIPortRef inPort;
	MIDIInputPortCreate(client, CFSTR("Input port"), MIDIRead, instrumentUnit, &inPort);
    
    MIDIEndpointRef source = MIDIGetSource(sourceNo);
    CFStringRef endpointName = NULL;
    MIDIObjectGetStringProperty(source, kMIDIPropertyName, &endpointName);

    MIDIPortConnectSource(inPort, source, (void *)endpointName);
    NSLog(@"Recieving MIDI data from %@", endpointName);
}

#pragma mark - Main
int main (int argc, const char * argv[])
{
	@autoreleasepool {

    audioGraphSetup();
        
    listSources();           //See which sources you'd like to connect and then connect them as below.

    MIDISetupWithSource(0);
    //MIDISetupWithSource(6);  //Connecting source 6 - Novation Launchpad.
    //MIDISetupWithSource(7);  //Connecting source 7 - Livid Code.

	CFRunLoopRun();          //Loop this for constant data updates.

    }
	return 0;
}

#pragma mark Unused function for next commit.
void setupMIDI() { //Currently unused function.
	
	MIDIClientRef client;
	MIDIClientCreate(CFSTR("SuperSimpleMIDIIn"), NotificationProc, instrumentUnit, &client);
    
	MIDIPortRef inPort;
	MIDIInputPortCreate(client, CFSTR("Input port"), MIDIRead, instrumentUnit, &inPort);
    
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

