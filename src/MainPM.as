package
{
	import com.bykoko.domain.AppDomain;
	import com.bykoko.domain.Constants;
	import com.bykoko.infrastructure.message.ServiceMessage;
	import com.bykoko.infrastructure.task.SequentialContextTaskGroup;
	import com.bykoko.infrastructure.task.TaskLoadDefaultDesign;
	import com.bykoko.infrastructure.task.TaskLoadDefaultProduct;
	import com.bykoko.infrastructure.task.TaskLoadOrder;
	import com.bykoko.infrastructure.task.TaskLoadOrderProduct;
	import com.bykoko.infrastructure.task.TaskRecreateOrderDesigns;
	import com.bykoko.infrastructure.task.TaskRecreateOrderImages;
	import com.bykoko.infrastructure.task.TaskRecreateOrderTexts;
	import com.bykoko.infrastructure.task.TaskSetFirstAvailableProductDisplay;
	import com.bykoko.infrastructure.task.TaskUpdatePrice;
	import com.bykoko.util.DictionaryUtil;
	import com.bykoko.vo.FontDesigner;
	import com.bykoko.vo.order.EditableItem;
	import com.bykoko.vo.order.Order;
	import com.bykoko.vo.order.Product;
	import com.bykoko.vo.order.ProductDisplay;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.system.ApplicationDomain;
	import flash.system.SecurityDomain;
	import flash.text.Font;
	import flash.text.FontStyle;
	import flash.text.FontType;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.collections.SortField;
	import mx.core.FlexGlobals;
	import mx.events.StyleEvent;
	
	import org.spicefactory.lib.task.Task;
	import org.spicefactory.lib.task.events.TaskEvent;
	import org.spicefactory.lib.xml.XmlObjectMapper;
	import org.spicefactory.lib.xml.mapper.XmlObjectMappings;
	import org.spicefactory.parsley.core.context.Context;
	

	[Event(name="setupCompleted", type="flash.events.Event")]
	public class MainPM extends EventDispatcher
	{
		[MessageDispatcher]
		public var dispatcher:Function;
		
		[Inject]
		public var context:Context;
		
		[Inject]
		[Bindable]
		public var appDomain:AppDomain;
		
		
		
		/******************************************************************************
		 * PUBLIC METHODS
		 *****************************************************************************/

		
		//initial request of data when the application starts
		public function setup():void
		{
			dispatcher( new ServiceMessage(ServiceMessage.GET_CONFIG, getConfigCallback) );
		}

		
		
		//
		public function loadBootstrapData():void
		{
			//implementation of tasks with access to the context can be found here
			//blog.mattes-groeger.de/actionscript/context-aware-tasks/

			//start the creation of the bootstrap load process
			//the group of tasks to be done depends on the profile mode of the app:
			appDomain.bootstrapTaskGroup = new SequentialContextTaskGroup(context);
			appDomain.bootstrapTaskGroup.addEventListener(TaskEvent.COMPLETE, onBootstrapComplete);
			
			//check if exists an order to reproduce (2 options here: the owner is updating it or
			//another user is adding stuff to it to buy it)
			if(appDomain.orderFlashvars)
			{
				//load the product order
				appDomain.bootstrapTaskGroup.addTask(new TaskLoadOrder());

				//load the product used into the order
				appDomain.bootstrapTaskGroup.addTask(new TaskLoadOrderProduct());
				
				//if any, recreate designs of the order
				appDomain.bootstrapTaskGroup.addTask(new TaskRecreateOrderDesigns());
				
				//if any, recreate images of the order
				appDomain.bootstrapTaskGroup.addTask(new TaskRecreateOrderImages());
				
				//if any, recreate texts of the order
				appDomain.bootstrapTaskGroup.addTask(new TaskRecreateOrderTexts());
				
				//once all the editable items has added to the product, force
				//to show the first available display of the product (so the
				//editable items for this display will be added to the stage)
				appDomain.bootstrapTaskGroup.addTask(new TaskSetFirstAvailableProductDisplay());
			}
			else
			{
				//load the default product
				appDomain.bootstrapTaskGroup.addTask(new TaskLoadDefaultProduct());
				
				//there is a design to be used as default, it needs to be added to the product
				if(appDomain.defaultDesignId > 0)
				{
					appDomain.bootstrapTaskGroup.addTask(new TaskLoadDefaultDesign(appDomain.defaultDesignId));
				}
			}
			
			//update the price
			appDomain.bootstrapTaskGroup.addTask(new TaskUpdatePrice());
			
			appDomain.bootstrapTaskGroup.start();
		}
		
		
		
		//
		public function loadOrder():void
		{
			var mapper:XmlObjectMapper = XmlObjectMappings.
				forUnqualifiedElements().
				withRootElement(Order).
				mappedClasses(Order, Product, ProductDisplay, EditableItem).build();
			
			appDomain.order = mapper.mapToObject(Constants.tempOrder) as Order;
		}
		
		
		
		/******************************************************************************
		 * PRIVATE METHODS
		 *****************************************************************************/
		
		
		
		private function getConfigCallback():void
		{
			//get the domain
			appDomain.URL_ROOT = appDomain.config.url_root + "/"
			appDomain.URL_SERVICE = appDomain.URL_ROOT + "php/ajax/api.php";
			appDomain.URL_SEND_ORDER = appDomain.URL_ROOT + "php/ajax/get_data.php";
			appDomain.URL_FILE_UPLOAD = appDomain.URL_ROOT + "php/ajax/upload_designer.php";
			dispatcher( new ServiceMessage(ServiceMessage.GET_CATEGORIES, getCategoriesCallback) );
		}
		
		private function getCategoriesCallback():void
		{
			dispatcher( new ServiceMessage(ServiceMessage.GET_SUBCATEGORIES, getSubcategoriesCallback) );
		}
		
		private function getSubcategoriesCallback():void
		{
			dispatcher( new ServiceMessage(ServiceMessage.GET_DESIGN_CATEGORIES, getDesignCategoriesCallback) );	
		}
		
		private function getDesignCategoriesCallback():void
		{
			//load the external stylesheet, which contains the fonts to be used when adding texts
			var styleEvent:IEventDispatcher;
			CONFIG::debug
			{
				styleEvent = FlexGlobals.topLevelApplication.styleManager.loadStyleDeclarations2("textfonts.swf", true, ApplicationDomain.currentDomain, SecurityDomain.currentDomain);
			}
			CONFIG::release
			{
				styleEvent = FlexGlobals.topLevelApplication.styleManager.loadStyleDeclarations2(appDomain.URL_ROOT + "designer/textfonts.swf", true, ApplicationDomain.currentDomain, SecurityDomain.currentDomain);
			}
			styleEvent.addEventListener(StyleEvent.COMPLETE, onExternalStyleSheetLoaded);
		}



		private function onExternalStyleSheetLoaded(event:StyleEvent = null):void
		{
			//save into the domain only the external fonts that will be
			//design fonts to be used when creating products
			var designFonts:Dictionary = new Dictionary();
			for each(var font:Font in Font.enumerateFonts())
			{
				if(designFonts[font.fontName] == null && font.fontType == FontType.EMBEDDED_CFF)
				{
					//new font family, save it
					designFonts[font.fontName] = new FontDesigner(font);
				}

				//save the typeface of this font family
				if(font.fontStyle == FontStyle.BOLD)
					(designFonts[font.fontName] as FontDesigner).bold = true;
				if(font.fontStyle == FontStyle.ITALIC)
					(designFonts[font.fontName] as FontDesigner).italic = true;
				if(font.fontStyle == FontStyle.BOLD_ITALIC)
					(designFonts[font.fontName] as FontDesigner).boldItalic = true;
			}
			
			//save design fonts into the domain
			appDomain.designFonts.addAll(new ArrayCollection(DictionaryUtil.values(designFonts)));
			var sort:Sort = new Sort();
			sort.fields = [new SortField("fontName", false, false)];
			appDomain.designFonts.sort = sort;
			appDomain.designFonts.refresh();
			
			//notify that the setup is completed
			dispatchEvent( new Event("setupCompleted"));
		}

		
		
		private function onBootstrapComplete(event:TaskEvent):void
		{
			appDomain.bootstrapTaskGroup.removeEventListener(TaskEvent.COMPLETE, onBootstrapComplete);
			appDomain.bootstrapTaskGroup = null;
		}
	}
}