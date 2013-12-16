// ================================================================================
// PUBLIC CLASS: SSinMulti
// File        : SSinMulti.ck
// Author      : Dave Haynie
// Date        : 2013-Dec-10
// License     : Do what thou will shall be the whole of the law
// Dependencies: NONE
// ================================================================================
// Sliding oscillator with harmonics 
//    freq(float:r/w)             primary oscillator frequency (Hz), phase-matched
//    sfreq(float:r/w)            primary oscillator frequency (Hz)
//    phase(float:r/w)            current phase
//    sync(int:r/w)               (0) sync frequency to input, (1) sync phase to input, (2) fm synth
//    duration(dur:r/w)           duration of frequency slide
//    resolution(int:r/w)         resolution of frequency slide 
//    images(int:r/w)             number of images
//    imageType(int:r/w)          0 = all, 1 = odd, 2 = even, 3 = fixed
//    imageDecay(float:r/w)       gain loss from image to image
//    step(float:r/w)             oscillator offset for mode 3
//    gain(float:r/w)             set volume, also floats like frequency

public class SSinMulti extends Chubgraph {
    // The oscillator
    SinOsc osc[];
    Gain mix; 
    
    // slide tracking
    float target_freq;
    float last_freq;
    float target_gain;
    float last_gain;
       
    // slide parameters
    dur slide_dur;
    int slide_res;
    
    // Multi data
    int image_count;
    int image_type;
    float image_step;
    float image_decay;
    float root_freq;
    float root_gain;
    
    // Default oscillator
    null @=> osc;
    mix => outlet;
    
    // Default/init values. 
    1       => this.images;
    200::ms => this.duration;
    50      => this.resolution;
    0       => this.type;
    100.0   => this.step;
    0.95    => this.imageDecay;    
     
    // ===========================================================================
    // Slider shred. This makes the frequency change over time. Doesn't work right
    // for step adjustments.    
    fun void slide_freq() { 
        if (0 == last_freq) {
            target_freq => this.freqNow;
        } else {            
            duration() / resolution() => dur slider;
            (target_freq - this.freq()) / resolution() => float freq_step;
            (target_gain - this.gain()) / resolution() => float gain_step;
            
            for (0 => int i; i < resolution(); ++i) {
                this.freq() + freq_step  => root_freq;
                this.gain() + gain_step  => root_gain;
                setImages();
                slider => now; 
            }
        }
    }
    
    // Methods, basically proxies for SinOsc methods. 
    
    // Image management
    fun void imageDestruct() {
        if (null != osc) {
            for (0 => int i; i < images(); ++i) {
                osc[i] =< mix;
            }
        } 
    }
    
    fun int images(int img) {
        imageDestruct();
        img => image_count;
        new SinOsc[image_count] @=> osc;
        1 => osc[0].gain;
        
        for (0 => int i; i  < img; ++i) {
            osc[i] => mix;
        }
        1.0 / img => mix.gain;     
        setImages();
        return img; 
    }
    
    fun int images() {
        return image_count;
    }
    
    // Set the images
    fun float setImages() {
        root_freq => osc[0].freq;
        root_gain => osc[0].gain;
        
        if (images() < 2) return root_freq;
            
        if (0 == image_type) {
            for (1 => int i; i < images(); ++i) {
                osc[i-1].freq() * 2            => osc[i].freq;
                osc[i-1].gain() * imageDecay() => osc[i].gain;
            }
        } else if (1 == image_type) {
            osc[0].freq() * 2            => osc[1].freq;
            osc[0].gain() * imageDecay() => osc[1].gain;
            
            for (2 => int i; i < images(); ++i) {
                osc[i-1].freq() * 4            => osc[i].freq;
                osc[i-1].gain() * imageDecay() => osc[i].gain;
            }            
        } else if (2 == image_type) {
            for (1 => int i; i < images(); ++i) {
                osc[i-1].freq() * 4            => osc[i].freq;
                osc[i-1].gain() * imageDecay() => osc[i].gain;
            }
        } else if (3 == image_type) {
             for (1 => int i; i < images(); ++i) {
                osc[i-1].freq() + image_step   => osc[i].freq;
                osc[i-1].gain() * imageDecay() => osc[i].gain;
            }
        }
        return root_freq;
    }
    
    // Frequency Setting 
    fun float freqNow(float f) {
        f => root_freq;
        return setImages();
    }        
        
    fun float freq(float f) {
        f => root_freq;
        
        if (0.0 == last_freq || 0.0 == root_freq) {
            root_freq => this.freqNow;
        } else {
            root_freq => target_freq;
            spork ~ slide_freq();            
        }
        root_freq => last_freq;
        return root_freq;
    }
    
    fun float freq() {
        return osc[0].freq();
    }
    
    // Gain setting, also uses slider
    fun float gainNow(float g) {
        g => root_gain;
        setImages();
        return g;
    }
    
    fun float gain(float g) {
        g => root_gain;
        if (0.0 == last_gain && 0.0 == root_gain) {
            root_gain => this.freqNow;
        } else {
            root_gain => target_gain;
            spork ~ slide_freq();
        }
        root_gain => last_gain;
        return root_gain;
        
    }
    fun float gain() {
        return osc[0].gain();
    }   
    
    // Sync. Hooking up the inlet full time as the input to
    // the oscillator doesn't work for some reason. So this
    // is connected if we're going to use it. 
    fun int sync(int s) {
        if (-1 == s) {
            for (0 => int i; i < images(); ++i) {
                inlet =< osc[i];
            }
            0 => s;
        } else {
            for (0 => int i; i < images(); ++i) {
                inlet => osc[i];
            }
        }
        return s;
    }
    fun int sync() {
        return osc[0].sync();
    }
    
    // Image decay is the drop in amplitude from one image to the next, as a
    // percentage of the current gain. 
    
    fun float imageDecay(float hd) {
        hd => image_decay;
        setImages();
        return hd;
    }
    fun float imageDecay() {
        return image_decay;
    }
    
    // The type of multi-image oscillator
    fun int type(int t) {
        t => image_type;
        setImages();
        return t;
    }
    fun int type() {
        return image_type;
    }    
    
    // Step is for non-multiple image modes
    fun float step(float s) {
        return (s => image_step);
    }
    fun float step() {
        return image_step;
    }    

    // Phase
    fun float phase(float p) {   
        for (0 => int i; i < images(); ++i) {
            p => osc[i].phase;
        }
        return p;
    }
    fun float phase() {
        return osc[0].phase();
    } 
    
    // Duration is the length of the slide. 
    fun dur duration(dur d) {
        return (d => slide_dur);
    }
    fun dur duration() {
        return slide_dur;
    }
    
    // Resolution is the number of adjustment steps
    fun int resolution(int r) {
        return (r => slide_res);
    }
    fun int resolution() {
        return slide_res;
    }
}

/*

// Test it here

SSinMulti slider => dac;
5 => slider.images;
0.4 => slider.imageDecay;

for (0 => int type; type < 8; ++type) {  
    if (type < 3) {
        <<< "mode", type >>>;
        type => slider.type;
    } else {
        <<< "mode 3, step", (type-2.0)*50.0 >>>;
        (type-2.0)*50.0 => slider.step;
        3 => slider.type;
    }
        
    220 => slider.freq;
    1::second => now; 

    440 => slider.freq;
    1::second => now;

    0 => slider.freq;
    250::ms => now;

    220 => slider.freq;
    500::ms => now;

    440 => slider.freq;
    500::ms => now;

    0 => slider.freq;
    250::ms => now;
 }
*/