// ================================================================================
// PUBLIC CLASS: DrumKit
// File        : DrumKit.ck
// Author      : Dave Haynie
// License     : Freeware
// Date        : 2013-Dec-15
// Dependencies: IFB
// ================================================================================
// This is a general purpose percussion synthesizer. Percussive sounds tend to 
// start very sharply, then taper off to more or less a sine wave. The main signal
// chain here drives a filtered step generator to modulate a sine oscillator. 
// A noise generator also modulates the sine oscillator, adding a percussive
// nature to the waveform and basically helping to "un-pitch" the sound... drum
// sounds aren't supposed to be thought of as pitched instruments, unless of 
// course you're specifially after pitched-type drums. In keeping with the
// idea of "drum circle", I wanted mostly primitive sounding percussion, but I
// found the start of hihat and snare sounds, which I though I might double
// with the limited WAV sounds we have to make something interesting in those
// families. The main goal here were sticks, log, and bongo, though I added a kick/bass
// patch for use on my final project in the CalArts ChucK MOOC. Anyway, while you can
// probably use ADSR envelopes for this too, since we have Impulse generators, 
// I use these to "hit" things, with feedback to keep that hit around but decaying
// as long as the sound mandates. There's an impulse to drive the drum oscillator
// and the noise oscillator.
// 
//  in -> [ step ] -> [ LPF ] -+-> [ SinOsc ] -+-> [ mixer ] -> [ comp] -> [ LPF ] -> [ sine envelope] -> out
//                             |               |
//   [ Noise ] -+-> [ mixer ] -+               |
//              |                              |
//   [ IFB   ] -+                              |
//                                             |
//   [ IFB   ] --------------------------------+
//
// The idea for this comes from several places. I've been messing with improving
// and expanding drum sounds for the last several weeks, particularly last week
// in trying to make a good ride cymbal sound for "Jazz" week. I also highly
// recommend Sound On Sound, and in particular, the 63-part "Synth Secrets" 
// series. They start with percussive instruments in #33, and go on to cover
// Bass, Snare, and other drum sounds. These certainly won't write your ChucK
// code for your, they're thinking in terms of patching for commercially available
// hard (and by extension, soft) synthesizers. But there's nothing discussed that
// couldn't be worked into a ChucK program. What I did here is kind of a 
// simplified generic synth patch for percussion. Ok for some drums, but see "Synth
// Secrets" #35 if you really want to learn how to build a betetr snare drum. It
// ain't simple. 

public class DrumKit extends Chubgraph {
    // Main graph
    
    inlet => Step step => LPF step_flt => SinOsc drum_osc => Gain drum_mix => Dyno comp => LPF out_flt => SinOsc env => outlet;
 
    // Noise also modulates the drum oscillator
    Noise mod => Gain mod_mix => drum_osc;
    
    // Drum impulse graph. An impulse with feedback can modulate the drum oscillator
    IFB drum_imp => drum_mix;

    // Another impulse with feedback to modulate the noise
    IFB noise_imp => mod_mix;

    // Make the last SinOsc basically an envelope by syncing phase. This reduces some
    // of the harsh nature of the step-derived basis function. For some patches, this
    // didn't do much, for others, it's critical. 
    1 => env.sync;
    
    // The "mixer" stages are frequency mixers, not amplitude mixers. A true frequency 
    // mixer produces the sum and difference of every combination of frequencies 
    // going into it. The last-stage LPF is necessary to tame this, otherwise you
    // get a reall mess of unnecessary mixer products. 
    3 => drum_mix.op;   
    3 => mod_mix.op;  
    
    // Set up the compressor
    comp.compress();    
    6 => comp.ratio;
    
    // Default step filter frequency
    500.0 => step_flt.freq;
    1.0   => step_flt.Q;

    // Sound presets. These primarily set the step frequency, filter, mixer, and the
    // two impulse feedback loops to create the sound I'm after. These are just
    // tweaked by ear, there's no magic forumla. The tweak parameter allows for
    // small variations in sound, for finding just the right "log" sound for
    // one's drum circle, or using some randomness to make the sound more
    // interesting. 
    
    fun void stick(float tweak) { 
        1100.0 + 300.0 * tweak => step.next;
        1800.0                 => out_flt.freq;
        6.0                    => out_flt.Q;
        0.990                  => drum_imp.feedback;
        0.97 + tweak/30.0      => noise_imp.feedback;   
        200.0                  => mod_mix.gain;
    } 
    
    fun void log(float tweak) {  
        20.0 + 40.0 * tweak    => step.next;
        80.0                   => out_flt.freq;
        6.0 + 3.0 * tweak      => out_flt.Q;
        0.9985 - 0.015 * tweak => drum_imp.feedback;
        0.9960 - 0.015 * tweak => noise_imp.feedback; 
        300.0                  => mod_mix.gain;
    }  
    
    fun void bass(float tweak) {
        20.0 + 20.0 * tweak    => step.next;
        70.0                   => out_flt.freq;
        6.0                    => out_flt.Q;
        0.9995 - 0.015 * tweak => drum_imp.feedback;
        0.9950 - 0.015 * tweak => noise_imp.feedback;
        450.0                  => mod_mix.gain;
    }
       
    fun void bongo(float tweak) {
        50.0  +  200.0 * tweak => step.next;
        200.0 +  200.0 * tweak => out_flt.freq;
        2.0   +    4.0 * tweak => out_flt.Q;
        0.9985 - 0.004 * tweak => drum_imp.feedback;
        0.998                  => noise_imp.feedback; 
        20.0                   => mod_mix.gain;
    }

    fun void hihat(float tweak) {
        4500.0                 => step.next;       
        12000.0 - 6000 * tweak => out_flt.freq;
        1.0 + 2.0 * tweak      => out_flt.Q;
        0.995                  => drum_imp.feedback;
        0.9999 - 0.005 * tweak => noise_imp.feedback;
        12000.0                => mod_mix.gain;
    } 
    
    fun void snare(float tweak) {
        650.0 + 200.0 * tweak  => step.next;        
        9000.0                 => out_flt.freq;
        1.0                    => out_flt.Q;
        0.9985 - 0.003 * tweak => drum_imp.feedback;
        0.9998                 => noise_imp.feedback; 
        2400.0                 => mod_mix.gain;
    }
      
    
    // This is the stick hit, could be made into a NoteOn I
    // suppose -- same idea. All drum hits naturally stop
    // by themselves, because of the impulse origin, so
    // there's no need for NoteOff, though I suppose I could
    // add a dampen() function at some point (think of a 
    // hand drummer muting the bongo, or quieting a cymbal
    // with a touch.. that's what the dampen() would do. 
    // Subtracting the current output level from the next
    // strike, when there's still energy in the system, 
    // models what would really happen when you hit a still-
    // moving drum head -- the energy could be against or with
    // the energy of the new percussive strike. 
    fun float strike(float sticks) {
        sticks - noise_imp.last() => noise_imp.next; 
        sticks -  drum_imp.last() => drum_imp.next;
        return sticks;
    }
}

/* // test code

DrumKit drum => dac;

for (int i; i < 14; i++) {
    Math.random2f(0,1) => drum.bongo;
    Math.random2f(0.5,1.0) => drum.strike;
    100::ms => now;
}
*/