module cpu_bcd(input wire [7:0] binary,
           output reg [3:0] hundreds,
           output reg [3:0] tens,
           output reg [3:0] ones);

    integer i;

    // Based on the Binary to BCD conversion algorithm from https://my.eng.utah.edu/~nmcdonal/Tutorials/BCDTutorial/BCDConversion.html
    always @(*) begin
        // Set everything to 0
        hundreds = 0;
        tens = 0;
        ones = 0;

        for (i=7; i >= 0; i=i-1)
        begin
            if(hundreds >= 5)
                hundreds = hundreds + 3;
            if(tens >= 5)
                tens = tens + 3;
            if(ones >= 5)
                ones = ones + 3;

            // Shift everything to the left by one
            hundreds = hundreds << 1;
            hundreds[0] = tens[3];

            tens = tens << 1;
            tens[0] = ones[3];

            ones = ones << 1;
            ones[0] = binary[i];
        end
    end
    
endmodule