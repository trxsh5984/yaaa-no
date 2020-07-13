#include <stdio.h>
#include <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <arm_neon.h>
/*
WELL WELL WELL FUCKING MARIE, I DIDNT GET PAID SHIT FOR MY WORk. FUCK YOU
*/
#include "./Lua/LuauTranspiler.h"
@interface InputCapture : UIView @end

NSString* randomString(int length)
{
    static const char __alphabet[] =
        "0123456789"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "abcdefghijklmnopqrstuvwxyz";
    NSMutableString* randomString = [NSMutableString stringWithCapacity : length];
    u_int32_t alphabetLength = (u_int32_t)strlen(__alphabet);
    for (int i = 0; i < length; i++) {
        [randomString appendFormat : @"%c", __alphabet[arc4random_uniform(alphabetLength)]] ;
    }
    return randomString;
}

/* external definitions */
#define DF(Name, Address, Return, ...) typedef Return(__fastcall *t_##Name)(__VA_ARGS__); static t_##Name Name = (t_##Name)offsetLoc(Address); 
static long long offsetLoc(long long address) {
    return address + (long long)_dyld_get_image_vmaddr_slide(0);
}

#define xua_State long long
typedef int(*xua_CFunction) (xua_State X);

typedef struct xuaL_Reg {
    const char* name;
    xua_CFunction func;
} xuaL_Reg;

namespace Offsets {
    long long xua_extraspace = 168;                             // Unable to create a new thread for %s  |  Look for xua_setidentity
    long long xua_newthread_address = offsetLoc(0x100F2551C);   // Unable to create a new thread for %s     |   Look for xua_newthread.
    long long xua_newthread_return = offsetLoc(0x1007C1D14);    // Unable to create a new thread for %s     |   Look for xua_newthread, and find the next instruction after call (after BL)
    DF(
        xua_readclosure, 0x100FBFF20, int, xua_State X, const char* chunkname, const char* code, long size
    ); // bytecode version mismatch   |   Container sub is the address.
    DF(
        xua_pushcclosure, 0x100F26CC4, void, xua_State X, xua_CFunction func, const char* funcname, int ups, xua_CFunction altfunc
    ); // xpcall   |   String is an argument to a sub, which is the address.
    DF(
        xua_pcall, 0x100F27E14, int, xua_State X, int args, int rets, int errorfunc
    ); // *** Value not found ***   |   Look for directly above: if (xua_pcall(X, 0, 1, 0))
    DF(
        xua_tolstring, 0x100F26198, const char*, xua_State X, int idx, size_t* size
    ); // *** Value not found ***   |   Look for directly above: if (xua_pcall(X, 0, 1, 0))
}

using namespace Offsets;
void xua_setidentity(xua_State X, long long identity) {
    *(long long*)(*(long long*)(X + xua_extraspace) + 48LL) = identity;
}
int xuaL_loadbuffer(xua_State X, const char* script, size_t len, const char* chunkname) {
    auto code = LuauTranspiler::compile(lua_open(), script);
    return xua_readclosure(X, chunkname, code.c_str(), code.size());
}

int xuaL_loadstring(xua_State X, const char* script) {
    return xuaL_loadbuffer(X, script, strlen(script), script);
}

int xua_dostring(xua_State X, const char* c) {
    xuaL_loadstring(X, c);
    xua_pcall(X, 0, 0, 0);
}

/* custom api */
namespace Environment {
    int loadstringFunc(xua_State X) {
        auto source = xua_tolstring(X, 1, NULL);
        if (!source)
            source = "error('Failed to load.')";
        xuaL_loadbuffer(X, source, strlen(source), [[@"=" stringByAppendingString:randomString(5)]UTF8String]);
        return 1;
    }

    static const xuaL_Reg custom_api[] = {
        {"loadstring",     loadstringFunc},
        {NULL, NULL}
    };

    int loadFunctions(xua_State X) {
        int size = 0;
        auto api = custom_api;

        for (; api->name; api++){
            xua_pushcclosure(X, api->func, api->name, 0, NULL);
            size++;
        }

        return size; // count of custom functions
    }
}

/* theos init, and lua injection */
namespace InjectCalamari {
    bool game_loaded = false;
    bool hook_applied = false;
    bool init_lua = true;

    xua_State (*xua_newthread)(xua_State X);

    long long xua_newthread_hook(xua_State X) {
        if ((long)__builtin_return_address(0) == xua_newthread_return) { // at this point, global state is passed to newthread
            while (init_lua) {
                init_lua = false;
                xua_setidentity(X, 6);
                //5048633661 main UI
                //5025426267 tronx
                xuaL_loadstring(
                    X, "print('Calamari-iOS Loaded...'); local args = {...}; spawn(function() local genCode = unpack(args); genCode(game:GetService('InsertService'):LoadLocalAsset('http://roblox.com/asset?id=5048633661&t=' .. tick()).Source)(unpack(args)); end)"
                );
                if (xua_pcall(X, Environment::loadFunctions(X), 0, 0)) {
                    NSLog(@"There was an error: %s", (char*)xua_tolstring(X, -1, 0));
                }
            }
        }
        return xua_newthread(X);
    }
};

%hook AppsFlyerUtils
    +(bool)isJailbrokenWithSkipAdvancedJailbreakValidation:(bool)arg2 { return NO; }
%end

%hook InputCapture
-(id)init:(CGRect)arg1 vrMode:(BOOL)arg2 {
    if (!InjectCalamari::game_loaded) {
        InjectCalamari::game_loaded = true;
        return %orig(); 
    } 
    else { 
        if (!InjectCalamari::hook_applied) {
            MSHookFunction((void*)(xua_newthread_address), (void*)&InjectCalamari::xua_newthread_hook, (void**)&InjectCalamari::xua_newthread);
            InjectCalamari::hook_applied = true;
        }
        InjectCalamari::init_lua = true;
    } 
    return %orig();
}
%end

