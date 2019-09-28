package es.unican.istr.mortadelo.gdm.transformations.gdm2document;

import java.util.ArrayList;
import java.util.List;

public class Tree<T> {
  private T data;
  private List<Tree<T>> children;

  public Tree(T rootData) {
    data = rootData;
    children = new ArrayList<Tree<T>>();
  }

  public Tree<T> add(T data) {
    for (Tree<T> child : children) {
      if (child.data.equals(data)) {
        return child; // not added to the tree
      }
    }
    Tree<T> newChild = new Tree<T>(data);
    children.add(newChild);
    return newChild;
  }

  public List<Tree<T>> getChildren() {
    return children;
  }

  @SuppressWarnings("unchecked")
  public boolean equals(Object obj) {
    if (obj instanceof Tree<?>) {
      return data.equals(((Tree<T>)obj).data);
    }
    return false;
  }

  public String toString() {
    StringBuilder s = new StringBuilder();
    String tabLevel = "";
    return this.serializeTree(s, tabLevel);
  }

  private String serializeTree(StringBuilder s, String tabLevel) {
    s.append(tabLevel + data + "\n");
    tabLevel += "\t";
    for (Tree<T> child : children) {
      child.serializeTree(s, tabLevel);
    }
    return s.toString();
  }
}