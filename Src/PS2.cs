
using System.Collections.ObjectModel;
using System.Diagnostics;

namespace System.Management.Automation;

static class PS2
{
	/// <summary>
	/// Gets BaseObject of PSObject or the original object.
	/// </summary>
	public static object ToBaseObject(this object value)
	{
		return value is PSObject ps ? ps.BaseObject : value;
	}

	/// <summary>
	/// Gets BaseObject of PSObject, unless PSCustomObject, or the original object.
	/// </summary>
	public static object ToBaseObject(this object value, out PSObject custom)
	{
		if (value is not PSObject ps)
		{
			custom = null;
			return value;
		}

		if (ps.BaseObject is not PSCustomObject)
		{
			custom = null;
			return ps.BaseObject;
		}

		custom = ps;
		return ps;
	}

	/// <summary>
	/// Gets true if the object type is the specified by template parameter.
	/// </summary>
	public static bool Is<T>(object value)
	{
		Debug.Assert(typeof(T) != typeof(PSObject));
		return (value is PSObject ps ? ps.BaseObject : value) is T;
	}

	/// <summary>
	/// Invokes the script with $_ set to the specified value and optional arguments.
	/// </summary>
	public static Collection<PSObject> InvokeWithContext(ScriptBlock script, object value)
	{
		var vars = new List<PSVariable> { new("_", value) };
		return script.InvokeWithContext(null, vars);
	}

	/// <summary>
	/// Returns a new list with unwrapped null, BaseObject, PSCustomObject objects.
	/// </summary>
	public static object[] UnwrapPSObject(IList<PSObject> source)
	{
		var target = new object[source.Count];
		for (int i = target.Length; --i >= 0;)
		{
			var x = source[i];
			if (x != null)
				target[i] = x.BaseObject is PSCustomObject ? x : x.BaseObject;
		}
		return target;
	}
}
