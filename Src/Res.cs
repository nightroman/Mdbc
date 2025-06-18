
namespace Mdbc;

public static class Res
{
	public const string ErrorEmptyDocument = "Document must not be empty.";
	public const string InputDocId = "Input document must have _id.";
	public const string InputDocNull = "Input document cannot be null.";
	public const string ParameterCommand = "Parameter Command must be specified and cannot be null.";
	public const string ParameterFilter1 = "Parameter Filter must be specified and cannot be null or empty string. To match all, use an empty document.";
	public const string ParameterFilter2 = "Parameter Filter must not be used with pipeline input.";
	public const string ParameterPipeline = "Parameter Pipeline must be specified and cannot be null.";
	public const string ParameterUpdate = "Parameter Update must be specified and cannot be null.";

	internal static string CannotConvert2(object from, object to)
	{
		return $"Cannot convert '{from}' to '{to}'.";
	}

	internal static string CannotConvert3(object from, object to, string error)
	{
		return $"{CannotConvert2(from, to)} -- {error}";
	}
}
