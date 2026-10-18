function value = ldpcGetSetting(settings, fieldName, defaultValue)
%LDPCGETSETTING Return a setting field or a default value.

if isstruct(settings) && isfield(settings, fieldName) && ~isempty(settings.(fieldName))
    value = settings.(fieldName);
else
    value = defaultValue;
end
end
