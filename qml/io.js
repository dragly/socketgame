
.pragma library

function applyProperties(object, properties) {
    if(!object){
        console.warn("WARNING: apply properties got missing object: " + object);
        return;
    }

    if(!object.hasOwnProperty("persistentProperties")) {
        console.warn("WARNING: Object " + object + " is missing persistentProperties property.");
        return;
    }

    for(var i in properties) {
        var prop = properties[i];
        var found = false;
        for(var j in object.persistentProperties) {
            var propertyGroup = object.persistentProperties[j];
            if(!propertyGroup.hasOwnProperty(i)) {
                continue;
            }
            found = true;
            if(typeof(prop) === "object" && typeof(propertyGroup[i]) == "object") {
                applyProperties(propertyGroup[i], prop);
            } else {
                propertyGroup[i] = prop;
            }
        }
        if(!found) {
            console.warn("WARNING: Cannot assign to " + i + " on savedProperties of " + object);
        }
    }
}

function generateProperties(entity) {
    if(!entity) {
        return undefined;
    }
    var result = {};
    for(var i in entity.persistentProperties) {
        var properties = entity.persistentProperties[i];
        for(var name in properties) {
            var prop = properties[name];
            if(typeof(prop) === "object") {
                result[name] = generateProperties(prop);
            } else {
                result[name] = prop;
            }
        }
    }
    return result;
}
