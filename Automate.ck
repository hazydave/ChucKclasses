// ================================================================================
// PUBLIC CLASS: Automate
// File        : Automate.ck
// Author      : Dave Haynie
// Date        : 2013-Dec-06
// Dependencies: NONE
// License     : Bend me, shape me, anyway you want me, long as you love me, it's all right. 
// ================================================================================
// This class creates a gain automation script. It accepts an array of waits, an 
// array of fade durations, and an array of new values. Create a subclass and
// override the "adj" methods to use. Example given at below. 

public class Automate {
    dur    t_set[];
    dur    t_fade[];
    float  adj_set[];
    
    20::ms => dur res;
    0      => int poison_pill;
    0      => int loopmode;

    // Methods
    
    // Set/get the times for change
    fun dur[] times(dur t[]) {
        return (t @=> t_set);
    }
    fun dur[] times() {
        return t_set;
    }
    
    // Set/get the fades
    fun dur[] fades(dur f[]) {
        return (f @=> t_fade);
    }
    fun dur[] fades() {
        return t_fade;
    }
    
    // Set/get the levels
    fun float[] levels(float l[]) {
        return (l @=> adj_set);
    }
    fun float[] levels() {
        return adj_set;
    }
    
    // Set/get the resolution of adjustment
    fun dur resolution(dur r) {
        return (r => res);
    }
    fun dur resolution() {
        return res;
    }
    
    // Subclass this to set what we're automating here. 
    fun float adj(float f) {
        return 0.0;
    }
    fun float adj() {
        return 0.0;
    }
    
    // Internal function for adjustment. This is sporked to run the 
    // automation as set up. 
    fun void runAuto() {
        int steps;
        float adj_val;
        float new_val;

        0 => int index; 
        while (index < t_set.cap() && 0 == poison_pill) { 
            // Wait the delay, then fade to the new value
            t_set[index] => now;
            
            // Figure out the number of steps to run, and the incremental value 
            Math.trunc(t_fade[index] / res) $ int => steps;
            (adj_set[index] - this.adj()) / steps => adj_val;
            this.adj() => new_val;
            // Do the fade
            for (0 => int change; change < steps && 0 == poison_pill; ++change) {
                adj_val +=> new_val;
                this.adj(new_val);
                res => now;
            }   
            
            // increment and perhaps loop
            1 +=> index;
            if (loopmode) index % t_set.cap() => index;
            
        }
        
        // Just make sure the final value is set accurately. 
        this.adj(adj_set[adj_set.cap()-1]);
    }
    
    // Just Do It!  May need a signal when disabling this.
    fun int enable(int e) {
        if (1 == e) {
            0 => poison_pill;
            spork ~ runAuto();
        } else {
            1 => poison_pill;
        }
    }

    fun int enable() {
        return !poison_pill;
    }     
   
   // Set/clear loop mode. 
   fun int loop(int l) {
      return (l => loopmode); 
   }
   fun int loop() {
       return loopmode;
   }
}

// ================================================================================
// Test code
/*

// This is just going to pan back and forth...could make it a sin pan with a
// little more ambition. 

SinOsc tester => Pan2 panner => dac;
0.8 => tester.gain;

class Panhandler extends Automate {
      // Subclass this to set what we're automating here. 
    fun float adj(float f) {
        return (f => panner.pan);
    }
    fun float adj() {
        return panner.pan();
    }  
}

Panhandler ph;
1::ms                         => ph.resolution;
[0.05::second, 0.05::second ] => ph.times;
[1.95::second, 1.95::second ] => ph.fades;
[1.0,                  -1.0 ] => ph.levels;
1 => ph.loop;
1 => ph.enable;

30::second => now;
*/
