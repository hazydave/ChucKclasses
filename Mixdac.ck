// ================================================================================
// PUBLIC CLASS: Mixdac
// File    : Mixdac.ck
// Author  : Dave Haynie
// Date    : 2013-Dec-07
// License : Do as thou wilt shall be the whole of the law
// Note    : PLEASE KEEP IF YOU FIND IT USEFUL
// ================================================================================
//
// This class defines a global class for multi-file final mixing. Mixdac is an all
// static version of MixMaster, which I handed out to the class for help with
// audio levelling. It supplies a DC blocking function, a global gain, stereo output,
// optional limiter or compressor, optional automatic gain control, and optional
// output level statistics (level metering). 
//
// Load "Mixdac" in your "initialization.ck" file, just like any other ChucK
// public class file. No need to create any Mixdac objects. 
//
//      Mixdac.init();  or  1 => Mixdac.init;
//
// Due to the magic of stereo objects, you chuck into MixMaster's in object, not to
// the MixMaster object itself. Example: 
// 
//      Mixdac master; 
//      SinOsc sin  => NRev sin_rvb  => Pan2 sin_pan  => master.in;
//      SndBuf kick => NRev kick_rvb => Pan2 kick_rvb => master.in;
//
// Mixmaster supports the following methods:
//
//     * init()               Init routine, used only by your score.ck file (only
//                            called once per project). 
//     * clear()              Reset the MixMaster to its default state. 
//     * meter(int:r/w)       Enable (1) or disable (0) the level metering stats. 
//     * meterLeftPeak()      Report the peak level of the left channel.
//     * meterRightPeak()     Report the peak level of the right channel. 
//     * meterReport()        Prettyprint a meter report
//     * agc()                Set/clear peaking AGC 
//     * compress()           Enable compression, default 2:1 ratio above 0.5 threshold
//     * compress(float:w)    Enable compression, supplying ratio
//     * limit()              Enable fairly hard limiting
//     * gain(float:r/w)      Set global gain for every module using any MixMaster object
//     * pan(float:r/w)       Set global pan for every module using any MixMaster object
//     * log(int:w)           Log output to a stereo file (0 = wav, 1 = au, 2 = aiff)

// ===========================================================================================
// PRIVATE CLASS LevelMeter
//
// First is a private class for monitoring audio levels and, using that information,
// optionally acting as a very simple automatic gain control. 

class LevelMeter extends Chugen {
    float peak;
    float peak_adj;
    float scale; 
    float last_scale;
    
    int agc_window;
    int agc_window_max;
    
    int enb;
    int mode;
    
    // Accessor functions for the various variables
    fun float audioPeak() {
        return peak;
    }
    fun float audioPeakAdj() {
        return peak_adj;
    }
    
    fun int enable(int e) {
        return (e => enb);
    }
    fun int enable() {
        return enb;
    }
    fun void clear() {
        0.0 => peak;
        0.0 => peak_adj;
        1.0 => scale;
        
        50  => agc_window_max;
        0   => agc_window;
         
        0 => mode;
        0 => enb;
    }
    
    // Simple AGC modes
    
    fun int agc(int md) {
        return (md => mode); 
    }
    
    fun int agc() {
        return mode;
    }
    
    fun float agcScale() {
        return scale;
    }
    
    // The ChuGen function, called for every sample
    fun float tick(float insmp) { 
        insmp => float outsmp;
        
        if (enable() || agc()) {
            // Compute peak and average
            Std.fabs(insmp) => float inmag;
            Math.max(peak, inmag) => peak;                       
            
            if (0 == ++agc_window % agc_window_max) { 
                scale => float old_scale;
                
                if (1 == mode && 1.0 < peak) {
                    1.0 / peak => scale;
                } 
                peak_adj * (scale/old_scale) => peak_adj;
            }
            insmp * scale => outsmp;
            Math.max(peak_adj, inmag * scale) => peak_adj;
        }
        return outsmp;
    }
}

// This Chubgraph is used as the output chain for mixer-like things. It's mono in, but can pan
// to the final dac, since it incorporates the dac. Using this as a subclass allows the usual
// initialization that doesn't happen within the Mixdac without being instantiated. 

class Outch extends Chubgraph {
    inlet => PoleZero dc => Dyno cpl => LevelMeter lvl;
    lvl => outlet; 
    
    // Back to normal
    fun void clear() {
        compress(1.0);
        lvl.clear();
    }   
    
    // Level meter functions
    fun int meter(int m) {
        m => lvl.enable;
        return lvl.enable();
    }
    fun int meter() {
        return lvl.enable();
    }
    fun float meterPeak() {
        return lvl.audioPeak();
    }
    fun float meterPeakAdj() {
        return lvl.audioPeakAdj();
    }

    fun void meterReport(string preface) {
        if (lvl.enable()) {
            if (lvl.agc()) {
                <<< preface, "peak:", lvl.audioPeak(),  "peak out:", lvl.audioPeakAdj(),  "scale:", lvl.agcScale() >>>;
            } else if (agc()) {
                <<< preface, "peak:", lvl.audioPeakAdj() >>>;
            } else {
                <<< preface, "peak:", lvl.audioPeak() >>>;
            }
        }
    }    
    // AGC functions
    fun int agc(int mode) {
        mode => lvl.agc;
        return mode;
    }
       
    fun int agc() {
        return lvl.agc();
    }
    
    // Compressor/limiter functions
    fun void compress() {
        cpl.compress();
    }
    fun void compress(float ratio) {
        if (ratio < 1.0) 1.0 => ratio; // Avoids evil
        compress();
        ratio => cpl.ratio;
    }
    fun void limit() {
        cpl.limit();
    }
}


// ===========================================================================================
// PUBLIC CLASS MixMaster
// 
// This is a class for dealing with the final mixdown of multiple classes. This
// creates a global output bus with some signal chain things you'd probably like
// in a final mixer. This is tricky, because ChucK doesn't handle static inits 
// properly -- they're done per use, not one-time as you'd get in other languages. 
// So I create explicit constructor and destructor functions, which work... at
// least most of the time. 

public class Mixdac {   
    static Pan2 @ in;               // Input pan  
    static Outch @ left;            // Left signal chain
    static Outch @ right;           // Right signal chain
    static int constructed;         // Getting around the lack of proper static inits and all that. 
     
    // Constructor function.. only runs once per session. 
    fun static int init(int dummy) {     
        // This is the clean-up function of the constructor. ChucK doesn't seem to like these
        // connections to persist from run to run; either the objects are disconnected, or the
        // ChucK environment crashes, if they're not de-ChucKed. Could be a big in this code, 
        // but I have not found it. 
        if (2 == constructed) {
            in.left  =< left  =< dac.left;
            in.right =< right =< dac.right;

            1 => constructed;
        }
    
        // This is the static constructor function, called only once, ever. Sure would be nice if
        // ChucK did static inits or had some other static initialization functionality, but since
        // it does reset ints to zero, at least I can fudge it. 
        if (0 == constructed) {
            // Build all the dynamic stuff we can't statically init as, well, static
            // variables. These are all run-permanent, we never need to free them. 
            new Pan2 @=> in;
            new Outch @=> left;
            new Outch @=> right;
        
            // Mark this initialization stage. 
            1 => constructed;
        }
        
        // This function links up the audio chain used within the Mixdac. 
        if (1 == constructed) {
            in.left  => new Outch @=> left  => dac.left;
            in.right => new Outch @=> right => dac.right;  
            clear();
            
            2 => constructed;
        }
        return 0;
    }
    
    fun static int init() {
        init(1);
    }
    
    // Back to normal
    fun static void clear() {
        right.clear();
        left.clear();
    }   
    
    // Start logging this session. This is pulled from the dac, post-processing,
    // just to simplifing the signal chain and make this part automatically
    // clean up after itself. 
    fun static int log(int type, string filename) {  
        
        // get audion from the dac
        dac => WvOut2 logger => blackhole;

        me.dir() + "/" => logger.autoPrefix;
        
        // Create the specified file type
        if (0 == type) {
            filename => logger.wavFilename;
        } else if (1 == type) {
            filename => logger.sndFilename;
        } else if (2 == type) {
            filename => logger.aifFilename;
        }
        
        <<<"logging audio to: ", logger.filename()>>>;

        // Probably not necessary... de-linking the logger
        // causes it to close on spork end. That should happen
        // anyway when this function exist. 
        null @=> logger;        
    }
    
    // Log under a different file name
    fun static int log (int type) {
        return log (type,"special:auto");
    }  
    
    // Level meter functions
    fun static int meter(int m) {
        left.meter(m);
        right.meter(m);
        return left.meter() && right.meter();
    }
    fun static int meter() {
        return left.meter() && right.meter();
    }
    fun static float meterLeftPeak() {
        return left.meterPeak();
    }
    fun static float meterRightPeak() {
        return right.meterPeak();
    }

    fun static void meterReport(string preface) {
        if (meter()) {
            left.meterReport(preface  + "Left :");
            right.meterReport(preface + "Right:");
        }
    }
    fun static void meterReport() {
        meterReport("levels ");
    }
    
    // AGC functions    
    fun static int agc(int mode) {
        mode => right.agc => left.agc;
        return mode;
    }
    fun static int agc(int mode) {
        return right.agc();
    }
    
    // Compressor/limiter functions
    fun static void compress() {
        left.compress();
        right.compress();
    }
    fun static void compress(float ratio) {
        if (ratio < 1.0) 1.0 => ratio; // Avoids evil
        left.compress(ratio);
        right.compress(ratio);
    }
    fun static void limit() {
        left.limit();
        right.limit();
    }

    // Basic mix functions
    fun static float gain(float g) {
        return (g => in.gain);
    }
    fun static float gain() {
        return in.gain();
    }
    fun static float pan(float p) {
        return (p => in.pan);
    }
    fun static float pan() {
        return in.pan();
    }
}
    