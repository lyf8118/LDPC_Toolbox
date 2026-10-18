function settings = prepareB2bLdpcSettings(settings)
%PREPAREB2BLDPCSETTINGS Fill defaults required by B2b LDPC decoders.

if nargin == 0 || isempty(settings)
    settings = struct();
end

settings.messageType = ldpcGetSetting(settings, 'messageType', 'B2b');
settings.gfBits = ldpcGetSetting(settings, 'gfBits', 6);
settings.gfSize = ldpcGetSetting(settings, 'gfSize', 64);
settings.bitsPerSymbol = ldpcGetSetting(settings, 'bitsPerSymbol', 6);
settings.rowH = ldpcGetSetting(settings, 'rowH', 81);
settings.colH = ldpcGetSetting(settings, 'colH', 162);
settings.symbolsPerFrame = ldpcGetSetting(settings, 'symbolsPerFrame', 81);
settings.maxIterations = ldpcGetSetting(settings, 'maxIterations', 15);
settings.nmEms = ldpcGetSetting(settings, 'nmEms', 4);
settings.alpha = ldpcGetSetting(settings, 'alpha', 1.0);
settings.offset = ldpcGetSetting(settings, 'offset', 0);
settings.decoderType = ldpcGetSetting(settings, 'decoderType', 'EMS');

if ~isfield(settings, 'gfMulTable') || isempty(settings.gfMulTable)
    settings.gfMulTable = getGfTable();
end
end
