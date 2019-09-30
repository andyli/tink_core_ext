package tink.core.ext;

import haxe.macro.Expr;
import haxe.macro.Context;

using tink.CoreApi;
#if macro
using tink.MacroApi;
#end

class Promises {
	
	public static macro function multi(e:Expr):Expr {
		return switch haxe.macro.Context.typeof(e) {
			case TAnonymous(_.get() => {fields: fields}):
				
				var obj:Array<Field> = [];
				var exprs:Array<Expr> = [];
				
				for(field in fields) {
					var name = field.name;
					
					switch promiseType(field.type.toComplex()) {
						case TPath({name: 'DirectType', pack: ['tink', 'macro']}):
							field.pos.error('Cannot determine the type of ${field.name}, please hint its type explicitly');
						case ct: 
							obj.push({
								name: name,
								kind: FVar(ct),
								pos: field.pos,
								meta: [{name: ':optional', pos: field.pos}],
							});
							
							exprs.push(macro (__obj.$name:Promise<$ct>).handle(__ctx.handle(function(r, v) r.$name = v)));
					}
				}
				
				var ct = TAnonymous(obj);
				return macro @:pos(e.pos) {
					var __obj = $e;
					Promise.lift(Future.async(function(cb) {
						var __ctx = new tink.core.ext.Promises.Container<$ct>(cb, $v{fields.length});
						$b{exprs}
					}));
				}
				
			default:
				e.pos.error('Expected inline object declaration');
		}
	}
	
	#if macro
	static function promiseType(ct:ComplexType) {
		return Context.typeof(macro {
			function f<A>(p:tink.core.Promise<A>):A return null;
			f((null:$ct));
		}).toComplex();
	}
	#end
}

class Container<T:{}> {
	var result:T = cast {};
	var count:Int;
	var cb:Outcome<T, Error>->Void;
	
	public function new(cb, count) {
		this.cb = cb;
		this.count = count;
	}
	
	public function handle<R>(assign:T->R->Void) {
		return function(o) switch o {
			case Success(v):
				assign(result, v);
				if(--count == 0) cb(Success(result));
			case Failure(e):
				cb(Failure(e));
		}
	}
}