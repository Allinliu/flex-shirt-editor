package com.bykoko.util{	import flash.utils.Dictionary;		/**	 * The DictionaryUtils class contains utility methods for working	 * with dictionaries.	 * 	 * <script src="http://mint.codeendeavor.com/?js" type="text/javascript"></script>	 */	final public class DictionaryUtil	{				/**		 * Return an Array of all keys in the dictionary.		 *			 * @param d A dictionary who's keys will be returned.		 */							public static function keys(dict:Dictionary):Array		{			var a:Array=[];			var key:Object;			for(key in dict)a.push(key);			return a;		}				/**		 * Return an Array of all values in the dictionary.		 * 			 * @param A dictionary who's values will be returned.		 */							public static function values(dict:Dictionary):Array		{			var a:Array=[];			var value:Object;			for each(value in dict)a.push(value);			return a;		}	}}