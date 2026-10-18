function code = generateLfsrCode(codeLength, initialState, feedbackMask)
%GENERATELFSRCODE Generate a bipolar code with the BDS 13-stage LFSR.
%   This follows the ICD right-shifting register convention.

    register = uint16(initialState);
    feedbackMask = uint16(feedbackMask);
    registerLength = 13;
    code = ones(1, codeLength);

    for chipIndex = 1:codeLength
        outputBit = bitand(register, uint16(1));
        code(chipIndex) = 1 - 2 * double(outputBit);

        tappedBits = bitget(bitand(register, feedbackMask), ...
            1:registerLength);
        feedbackBit = mod(sum(tappedBits), 2);
        register = bitor(bitshift(register, -1), ...
            bitshift(uint16(feedbackBit), registerLength - 1));
    end
end
