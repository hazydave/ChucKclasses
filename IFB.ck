// ================================================================================
// PUBLIC CLASS: IFB
// Author      : Dave Haynie
// Date        : 2013-Dec-06
// License     : Do as thou wilt shall be the whole of the law
// Dependencies: NONE
// ===========================================================================
// This is a general purpose impulse/feedback loop that's useful in various 
// synthesizer ideas I'm messing with. It looks like this:
// 
//       in --> [impulse] -+-> [ Gain     ] --+-> out
//                         |                  |
//                         +<--[ Feedback ]<--+
//
// This class implements the following methods
//
// gain(float:r/w)      Set the forward path gain
// feedback(float:r/w)  Set the feedback path gain (defaults to zero)
// next(float:r/w)      Trigger the impulse


public class IFB extends Chubgraph {
    // Main graph
    inlet => Impulse imp => Gain imp_gain => outlet;
    
    // Feedback loop
    imp_gain => Gain imp_feedback => imp_gain;
    
    // Methods
    
    // Gain is managed in the main gain object
    fun float gain(float g) {
        return (g => imp_gain.gain);
    }
    fun float gain() {
        return imp_gain.gain();
    }
    
    // Feedback is adjusted through the feedback loop gain
    fun float feedback(float fb) {
        return (fb => imp_feedback.gain);
    }
    fun float feedback() {
        return imp_feedback.gain();
    }
      
    // Next is of course directed to the Impulse generator
    fun float next(float nx) {
       return (nx => imp.next);
    }
    fun float next() {
       return imp.next();
    }
} 