// -------------------------------------------------------------------------------------
// This file exports several useful functions
// -------------------------------------------------------------------------------------

// ---------------------------------------
// Returns the max of 2 integers: a and b
// ---------------------------------------
function integer max;
    input integer a, b;
    begin
        if (a > b)
            max = a;
        else
            max = b;
    end
endfunction
