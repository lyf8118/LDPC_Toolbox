function code = B2b_EMS_decode(llrMatrix, settings)
%B2B_EMS_DECODE Compatibility wrapper for the standardized EMS decoder.

if nargin < 2
    settings = struct('decoderType', 'EMS');
else
    settings.decoderType = 'EMS';
end

settings = prepareB2bLdpcSettings(settings);
[code, ~] = emsDecode(llrMatrix, settings);
end
