// ================================================================================
// PUBLIC CLASS: DFB
// Author      : Dave Haynie
// License     : Do as thou wilt shall be the whole of the law
// Date        : 2013-Dec-07
// ================================================================================
// This is a general purpose delay/feedback loop that's useful in various 
// synthesizer ideas I'm messing with. It looks like this:
// 
//       in -+-> [ Delay    ] --+-> out
//           |                  |
//           +<--[ Feedback ]<--+
//
// This class implements the following methods
//
// gain(float:r/w)      Set the forward path gain
// feedback(float:r/w)  Set the feedback path gain (defaults to zero)
// delay(dur:r/w)       Set the delay
// max(dur:r/w)         Set the maximum delay
// op(int:r/w)          Set the input mixer operation
// clear()              Set delay, feedback off, gain to 1.0.


public class DFB extends Chubgraph {
    // Main path
    inlet => Delay dly => outlet;
    
    // Feedback path
    dly => Gain fb => dly;
    
    // Set defaults
    this.clear();
    
    // methods
    
    // defaults set gain to unity, feedback and delay off, and filter off
    fun void clear() {
        1.0     => this.gain;
        0::ms   => this.delay;
        50::ms  => this.max;
        1.0     => this.gain;
        0.0     => this.feedback;
    }
    
    // Mixer operation
    
        
    // The gain method operates on the path Gain object
    fun float gain(float g) {
        return (g => dly.gain);
    }
    fun float gain() {
        return dly.gain();
    }
    // The fb method operates on the feedback Gain object
    fun float feedback(float g) {
        return (g => fb.gain);
    }
    fun float feedback() {
        return fb.gain();
    }
    // Several methods for delay adjustment
    fun dur delay(dur t) {
        return (t => dly.delay);
    }
    fun dur delay() {
        return dly.delay();
    }
    fun dur max(dur mx) {
        return (mx => dly.max);
    }
    fun dur max() {
        return dly.max();
    }
}
    
