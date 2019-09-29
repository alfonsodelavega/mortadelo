package es.unican.istr.mortadelo.gdm.transformations.gdm2document;

import java.util.ArrayList;
import java.util.List;

/**
 * Generic tree type where each nodes's children are a unique set
 * @author Alfonso de la Vega
 */
public class Tree<T> {
  private T data;
  private List<Tree<T>> children;

  public Tree(T rootData) {
    data = rootData;
    children = new ArrayList<Tree<T>>();
  }

  /**
   * If the data already exists, the existing tree node is returned, if not a
   *   new one is generated
   * @param data The element to include
   * @return A tree node where the data has been added (or where it was present)
   */
  public Tree<T> add(T data) {
    for (Tree<T> child : children) {
      if (child.data == null && data == null
          || child.data.equals(data)) {
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

  public T getData() {
    return data;
  }

  @SuppressWarnings("unchecked")
  public boolean equals(Object obj) {
    if (data == null || obj == null || !(obj instanceof Tree<?>)) {
      return false;
    }
    return data.equals(((Tree<T>) obj).data);
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