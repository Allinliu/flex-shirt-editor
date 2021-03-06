package com.bykoko.infrastructure.command
{
	import com.bykoko.domain.AppDomain;
	import com.bykoko.infrastructure.message.ServiceMessage;
	import com.bykoko.vo.xmlmapping.product.Articulo;
	import com.bykoko.vo.xmlmapping.product.Articulos;
	import com.bykoko.vo.xmlmapping.product.Back;
	import com.bykoko.vo.xmlmapping.product.Color;
	import com.bykoko.vo.xmlmapping.product.Colores;
	import com.bykoko.vo.xmlmapping.product.Front;
	import com.bykoko.vo.xmlmapping.product.Left;
	import com.bykoko.vo.xmlmapping.product.Posiciones;
	import com.bykoko.vo.xmlmapping.product.Right;
	import com.bykoko.vo.xmlmapping.product.Talla;
	import com.bykoko.vo.xmlmapping.product.Tallas;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.AsyncToken;
	
	import org.spicefactory.lib.xml.mapper.XmlObjectMappings;

	public class GetProductByIdCommand extends BaseCommand
	{
		[Inject]
		public var appDomain:AppDomain;

		
		
		//
		override public function execute(message:ServiceMessage):AsyncToken
		{
			super.execute(message);			
			return service.getProductById(message.idProduct);
		}
		
		
		
		//
		override public function result(data:Object):void
		{
			//map the xml response
			mapper = XmlObjectMappings.
				forUnqualifiedElements().
				withRootElement(Articulos).
				mappedClasses(Articulo, Posiciones, Front, Back, Left, Right, Colores, Color, Tallas, Talla).build();

			//save the products
			callbackParameters = [(mapper.mapToObject(data as XML) as Articulos).articulos[0]];
			super.result(data);
		}
	}
}