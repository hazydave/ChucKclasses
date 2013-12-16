// ================================================================================
// PUBLIC CLASS: Marimba
// File        : Marimba.ck
// Author      : Dave Haynie
// License     : Public Domain
// Date        : 2013-Dec-06
// Dependencies: DFB
// ================================================================================
// This is a general purpose filter/delay/feedback loop that's useful in various 
// synthesizer ideas I'm messing with. It looks like this:
// 
//       in -+-> [ModalBar] -+-> [ DFB ] -+-> [ Comp ] --+-> out
//           |               | 
//           +-> [TriOsc1 ] -+ 
//           |               |
//           +-> [TriOsc2 ] -+
 
// Define the marimba as a riff on the modal bar. Currently backed up with the 
// cascaded ADSRs I used for a xylophone a few weeks ago (this will be a xylophone
// at higher frequencies), but I might try messing with the blown bottle, maybe
// also through an ADSR to deliver the idea of tube resonating from the hit of the
// woodern block. Or not... not too bad right now. 
//
// This one is all from experimentation. It started out based on a Xylophone sound
// I did a few weeks back, which was inspired by some discussions in the KVR Audio
// forum suggesting two osciallators tuned two octaves apart as a good starting 
// point for xylophone. Here, I'm basically using using the ModalBar as the sound 
// of the xylophone blocks, and the ADSR plus oscillators to fill in the effect of
// the tuned reverberation tubes on these instruments. 

public class Marimba extends Chubgraph {
    inlet => ModalBar mb => DFB dly => Dyno comp => outlet;
    inlet => TriOsc osc1 => ADSR env1 => dly;
    inlet => TriOsc osc2 => ADSR env2 => dly;  
    
    // Inits
    6 => mb.preset;               // Set a mariba model; 
    0.7 => mb.stickHardness;      // All these other parameters
    0.5 => mb.strikePosition;
    0.1 => mb.directGain;
    1.0 => mb.gain;
    
    env1.set(5::ms,40::ms,0,10::ms);
    env2.set(5::ms,15::ms,0,10::ms);
    0.2 => env1.gain;
    0.2 => env2.gain;
    
    comp.compress();
    4.0 => comp.ratio;
    
    0.4 => dly.feedback;
    
    fun float freq(float f) {
        return (f => mb.freq);
    }
    fun float freq(int midi_note) {
        Math.mtof(midi_note) => mb.freq;
        mb.freq()            => osc1.freq;
        mb.freq() * 4        => osc2.freq;
        
        0.1 + (150.0-midi_note)/150.0 => dly.feedback;  
        return mb.freq();
    }
    fun float freq() {
        return mb.freq();
    }
   
    // Make the note
    fun float strike(float f) {
        f => mb.strike;
        //f => mb.noteOn;
        1 => env1.keyOn;
        1 => env2.keyOn;
        return f;
    }
    fun float damp(float f) {
        f => mb.damp;
        //f => mb.noteOff;
        1 => env1.keyOff;
        1 => env2.keyOff;
        return f;
    }    
}
