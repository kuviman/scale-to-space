module:

const C_String = @opaque_type "const char*";
const C_str = @opaque_type "const char*";

const C_String_from_str = (s :: &str) -> C_String => (
    @native "StringView_to_C_String(\(s))"
);

const C_String_drop = (self :: C_String) => (
    @native "Kast_free(\(self))";
);

const str_from_C_str = (s :: C_str) -> &str => (
    @native "StringView_from_C_StringView(\(s))"
);

const String_from_C_str = (s :: C_str) -> String => (
    @native "String_from_C_StringView(\(s))"
);

