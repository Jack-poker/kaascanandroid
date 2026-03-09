package com.google.appinventor.components.runtime.util;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

public class YailList extends ArrayList<Object> {
    public YailList() {
        super();
      
    }

    public static YailList makeList(List<?> objects) {
        YailList list = new YailList();
        list.addAll(objects);
        return list;
    }

    public static YailList makeEmptyList() {
        return new YailList();
    }

    @Override
    public int size() {
        return super.size() - 1; // AI2 list size excludes the header symbol
    }

    @Override
    public Object get(int index) {
        return super.get(index + 1); // AI2 list access is usually 1-indexed in Scheme but 0-indexed in Java getter if header is present
    }
}
